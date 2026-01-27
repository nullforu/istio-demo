"""
Demo Application with OpenTelemetry Instrumentation
====================================================
이 앱은 다음을 보여줍니다:
1. OpenTelemetry 자동 instrumentation (requests, redis, mongodb)
2. 커스텀 span 생성
3. httpbin 서비스 호출 (Istio trace 전파)
4. Redis 호출 트레이싱
5. MongoDB 호출 트레이싱
"""

import os
import time
import logging
from datetime import datetime
from flask import Flask, jsonify, request

import requests
import redis
from pymongo import MongoClient

# OpenTelemetry imports
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes

# Auto-instrumentation
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.pymongo import PymongoInstrumentor

# Logging 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# OpenTelemetry 설정
# ============================================================================

# 서비스 이름 설정
SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "demo-app")

# OTLP Exporter 엔드포인트 (Jaeger 또는 OTEL Collector)
OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "jaeger.observability.svc.cluster.local:4317")

# Resource 설정 (서비스 메타데이터)
resource = Resource.create({
    ResourceAttributes.SERVICE_NAME: SERVICE_NAME,
    ResourceAttributes.SERVICE_VERSION: "1.0.0",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "demo",
})

# TracerProvider 설정
provider = TracerProvider(resource=resource)

# OTLP Exporter 추가
otlp_exporter = OTLPSpanExporter(
    endpoint=OTLP_ENDPOINT,
    insecure=True,  # TLS 없이 연결
)
provider.add_span_processor(BatchSpanProcessor(otlp_exporter))

# 글로벌 TracerProvider 설정
trace.set_tracer_provider(provider)

# Tracer 인스턴스 생성
tracer = trace.get_tracer(__name__)

# ============================================================================
# Flask App 설정
# ============================================================================

app = Flask(__name__)

# Auto-instrumentation 활성화
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()
RedisInstrumentor().instrument()
PymongoInstrumentor().instrument()

# Redis 클라이언트 (연결 실패해도 앱 동작)
REDIS_HOST = os.getenv("REDIS_HOST", "redis.istio-demo.svc.cluster.local")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

try:
    redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
    redis_client.ping()
    REDIS_AVAILABLE = True
    logger.info(f"Redis connected: {REDIS_HOST}:{REDIS_PORT}")
except Exception as e:
    REDIS_AVAILABLE = False
    redis_client = None
    logger.warning(f"Redis not available: {e}")

# MongoDB 클라이언트 (연결 실패해도 앱 동작)
# Note: MONGODB_PORT conflicts with K8s service discovery env vars, so use MONGO_* prefix
MONGO_HOST = os.getenv("MONGO_HOST", "mongodb.istio-demo.svc.cluster.local")
MONGO_PORT = int(os.getenv("MONGO_PORT_NUM", "27017"))
MONGO_DB = os.getenv("MONGO_DB", "demo")

try:
    mongo_client = MongoClient(host=MONGO_HOST, port=MONGO_PORT, serverSelectionTimeoutMS=5000)
    mongo_client.server_info()
    mongo_db = mongo_client[MONGO_DB]
    MONGO_AVAILABLE = True
    logger.info(f"MongoDB connected: {MONGO_HOST}:{MONGO_PORT}")
except Exception as e:
    MONGO_AVAILABLE = False
    mongo_client = None
    mongo_db = None
    logger.warning(f"MongoDB not available: {e}")

# httpbin 서비스 URL
HTTPBIN_URL = os.getenv("HTTPBIN_URL", "http://httpbin.istio-demo.svc.cluster.local:8000")

# ============================================================================
# API Endpoints
# ============================================================================

@app.route("/")
def index():
    """헬스체크 및 앱 정보"""
    return jsonify({
        "service": SERVICE_NAME,
        "version": "1.0.0",
        "endpoints": [
            "GET /",
            "GET /trace-demo",
            "GET /call-httpbin",
            "GET /redis-demo",
            "GET /mongo-demo",
            "GET /full-demo",
        ],
        "redis_available": REDIS_AVAILABLE,
        "mongodb_available": MONGO_AVAILABLE,
    })


@app.route("/trace-demo")
def trace_demo():
    """
    커스텀 span 데모
    - 부모 span 아래에 자식 span 생성
    - span에 attributes 추가
    - span에 events 기록
    """
    with tracer.start_as_current_span("custom-operation") as span:
        # Span attributes 추가
        span.set_attribute("demo.type", "custom-span")
        span.set_attribute("demo.user", "student")
        
        # 첫 번째 작업
        with tracer.start_as_current_span("step-1-prepare"):
            time.sleep(0.1)
            span.add_event("Step 1 completed")
        
        # 두 번째 작업
        with tracer.start_as_current_span("step-2-process"):
            time.sleep(0.15)
            span.add_event("Step 2 completed")
        
        # 세 번째 작업
        with tracer.start_as_current_span("step-3-finalize"):
            time.sleep(0.05)
            span.add_event("Step 3 completed")
    
    return jsonify({
        "message": "Trace demo completed",
        "spans_created": ["custom-operation", "step-1-prepare", "step-2-process", "step-3-finalize"],
        "tip": "Jaeger에서 'demo-app' 서비스의 트레이스를 확인하세요",
    })


@app.route("/call-httpbin")
def call_httpbin():
    """
    httpbin 서비스 호출 데모
    - requests 라이브러리 자동 instrumentation
    - Istio sidecar와 trace context 전파
    - 여러 엔드포인트 호출
    """
    results = {}
    
    with tracer.start_as_current_span("httpbin-calls") as span:
        span.set_attribute("httpbin.url", HTTPBIN_URL)
        
        # GET /get 호출
        with tracer.start_as_current_span("call-httpbin-get"):
            try:
                resp = requests.get(f"{HTTPBIN_URL}/get", timeout=5)
                results["get"] = {"status": resp.status_code}
            except Exception as e:
                results["get"] = {"error": str(e)}
        
        # GET /headers 호출
        with tracer.start_as_current_span("call-httpbin-headers"):
            try:
                resp = requests.get(f"{HTTPBIN_URL}/headers", timeout=5)
                headers = resp.json().get("headers", {})
                # Trace 헤더 확인
                trace_headers = {k: v for k, v in headers.items() if k.startswith("X-")}
                results["headers"] = {"status": resp.status_code, "trace_headers": trace_headers}
            except Exception as e:
                results["headers"] = {"error": str(e)}
        
        # GET /delay/1 호출 (지연 테스트)
        with tracer.start_as_current_span("call-httpbin-delay"):
            try:
                start = time.time()
                resp = requests.get(f"{HTTPBIN_URL}/delay/1", timeout=5)
                duration = time.time() - start
                results["delay"] = {"status": resp.status_code, "duration_seconds": round(duration, 2)}
            except Exception as e:
                results["delay"] = {"error": str(e)}
    
    return jsonify({
        "message": "httpbin calls completed",
        "results": results,
        "tip": "Jaeger에서 demo-app → httpbin.istio-demo 호출 트레이스 확인",
    })


@app.route("/redis-demo")
def redis_demo():
    """
    Redis 호출 데모
    - redis 라이브러리 자동 instrumentation
    - SET/GET/INCR 명령어 트레이싱
    """
    if not REDIS_AVAILABLE:
        return jsonify({
            "error": "Redis not available",
            "message": "Redis 서비스를 배포하면 이 데모를 사용할 수 있습니다",
        }), 503
    
    results = {}
    
    with tracer.start_as_current_span("redis-operations") as span:
        span.set_attribute("redis.host", REDIS_HOST)
        
        # SET 명령
        with tracer.start_as_current_span("redis-set"):
            key = f"demo:timestamp:{int(time.time())}"
            redis_client.set(key, "hello from demo-app", ex=60)
            results["set"] = {"key": key, "ttl": 60}
        
        # GET 명령
        with tracer.start_as_current_span("redis-get"):
            value = redis_client.get(key)
            results["get"] = {"key": key, "value": value}
        
        # INCR 명령
        with tracer.start_as_current_span("redis-incr"):
            counter_key = "demo:counter"
            count = redis_client.incr(counter_key)
            results["incr"] = {"key": counter_key, "value": count}
    
    return jsonify({
        "message": "Redis demo completed",
        "results": results,
        "tip": "Jaeger에서 redis 명령어별 span 확인",
    })


@app.route("/mongo-demo")
def mongo_demo():
    """
    MongoDB 호출 데모
    - pymongo 라이브러리 자동 instrumentation
    - INSERT/FIND/AGGREGATE 작업 트레이싱
    """
    if not MONGO_AVAILABLE:
        return jsonify({
            "error": "MongoDB not available",
            "message": "MongoDB 서비스를 배포하면 이 데모를 사용할 수 있습니다",
        }), 503

    results = {}

    with tracer.start_as_current_span("mongo-operations") as span:
        span.set_attribute("mongodb.host", MONGO_HOST)
        span.set_attribute("mongodb.database", MONGO_DB)

        # INSERT 작업
        with tracer.start_as_current_span("mongo-insert"):
            doc = {
                "timestamp": datetime.now(),
                "action": "demo",
                "source": "demo-app"
            }
            insert_result = mongo_db.traces.insert_one(doc)
            results["insert"] = {"inserted_id": str(insert_result.inserted_id)}
            span.set_attribute("mongo.inserted_id", str(insert_result.inserted_id))

        # FIND 작업
        with tracer.start_as_current_span("mongo-find"):
            docs = list(mongo_db.traces.find().sort("timestamp", -1).limit(5))
            results["find"] = {"docs_found": len(docs)}
            span.set_attribute("mongo.docs_found", len(docs))

        # AGGREGATE 작업
        with tracer.start_as_current_span("mongo-aggregate"):
            pipeline = [
                {"$group": {"_id": "$action", "count": {"$sum": 1}}},
                {"$sort": {"count": -1}}
            ]
            agg_result = list(mongo_db.traces.aggregate(pipeline))
            results["aggregate"] = {"groups": len(agg_result)}
            span.set_attribute("mongo.aggregate_groups", len(agg_result))

    return jsonify({
        "message": "MongoDB demo completed",
        "results": results,
        "tip": "Jaeger에서 mongodb 작업별 span 확인",
    })


@app.route("/full-demo")
def full_demo():
    """
    전체 데모 - 모든 instrumentation 조합
    1. 커스텀 span
    2. Redis 호출
    3. MongoDB 호출
    4. httpbin 호출
    """
    with tracer.start_as_current_span("full-demo-flow") as span:
        span.set_attribute("demo.type", "full")
        results = {}

        # Step 1: 비즈니스 로직 (커스텀 span)
        with tracer.start_as_current_span("business-logic"):
            time.sleep(0.1)
            results["step1"] = "business logic completed"

        # Step 2: Redis 캐시 체크
        if REDIS_AVAILABLE:
            with tracer.start_as_current_span("cache-check"):
                cache_key = "demo:cache"
                cached = redis_client.get(cache_key)
                if not cached:
                    redis_client.set(cache_key, "cached-value", ex=30)
                    results["step2"] = "redis: cache miss - stored"
                else:
                    results["step2"] = "redis: cache hit"
        else:
            results["step2"] = "redis: not available"

        # Step 3: MongoDB 저장
        if MONGO_AVAILABLE:
            with tracer.start_as_current_span("mongodb-store"):
                doc = {"timestamp": datetime.now(), "action": "full-demo"}
                insert_result = mongo_db.traces.insert_one(doc)
                doc_count = mongo_db.traces.count_documents({})
                results["step3"] = f"mongodb: inserted {insert_result.inserted_id}, total docs: {doc_count}"
        else:
            results["step3"] = "mongodb: not available"

        # Step 4: 외부 서비스 호출 (httpbin)
        with tracer.start_as_current_span("external-api-call"):
            try:
                resp = requests.get(f"{HTTPBIN_URL}/get", timeout=5)
                results["step4"] = f"httpbin: returned {resp.status_code}"
            except Exception as e:
                results["step4"] = f"httpbin: error - {e}"

        # Step 5: 결과 처리
        with tracer.start_as_current_span("process-results"):
            time.sleep(0.05)
            results["step5"] = "results processed"

    return jsonify({
        "message": "Full demo completed",
        "flow": ["business-logic", "cache-check", "mongodb-store", "external-api-call", "process-results"],
        "results": results,
        "tip": "Jaeger에서 Redis, MongoDB, httpbin 3개 백엔드 호출을 한눈에 확인!",
    })


# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    logger.info(f"Starting {SERVICE_NAME} on port {port}")
    logger.info(f"OTLP Endpoint: {OTLP_ENDPOINT}")
    logger.info(f"Redis: {REDIS_HOST}:{REDIS_PORT} (available: {REDIS_AVAILABLE})")
    logger.info(f"MongoDB: {MONGO_HOST}:{MONGO_PORT} (available: {MONGO_AVAILABLE})")
    logger.info(f"httpbin URL: {HTTPBIN_URL}")
    app.run(host="0.0.0.0", port=port)
