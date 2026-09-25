import json
import os
import boto3

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")

MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
KB_BUCKET = os.environ.get("KB_BUCKET")


def handler(event, context):
    # Function URL requests arrive with a JSON string body; direct test
    # invocations may pass the dict straight through - handle both.
    body = json.loads(event["body"]) if isinstance(event.get("body"), str) else event

    ticket_text = body.get("ticket_text", "")
    key_phrases = body.get("key_phrases", [])

    draft_reply = draft_reply_with_bedrock(ticket_text, key_phrases)
    recommended_doc = recommend_doc_from_kb(key_phrases)

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "draft_reply": draft_reply,
            "recommended_doc": recommended_doc,
        }),
    }


def draft_reply_with_bedrock(ticket_text: str, key_phrases: list[str]) -> str:
    prompt = (
        "You are a support agent. Write a short, polite draft reply to this "
        f"customer ticket. Key topics detected: {', '.join(key_phrases) or 'none'}.\n\n"
        f"Ticket:\n{ticket_text}\n\nDraft reply:"
    )
    request_body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 300,
        "messages": [{"role": "user", "content": prompt}],
    }
    response = bedrock.invoke_model(modelId=MODEL_ID, body=json.dumps(request_body))
    result = json.loads(response["body"].read())
    return result["content"][0]["text"]


def recommend_doc_from_kb(key_phrases: list[str]) -> dict:
    lowered = [kp.lower() for kp in key_phrases]
    objects = s3.list_objects_v2(Bucket=KB_BUCKET).get("Contents", [])

    best_match, best_score = None, 0
    for obj in objects:
        raw = s3.get_object(Bucket=KB_BUCKET, Key=obj["Key"])["Body"].read()
        doc = json.loads(raw)
        score = sum(1 for kp in lowered if any(kp in tag for tag in doc.get("tags", [])))
        if score > best_score:
            best_score, best_match = score, doc

    return best_match or {"title": "General Help Center", "url": "https://example.com/help"}
