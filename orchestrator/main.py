import os
import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Multi-Cloud AI Support Agent Orchestrator")

AZURE_ENDPOINT = os.environ.get("AZURE_LANGUAGE_ENDPOINT", "")
AZURE_KEY = os.environ.get("AZURE_LANGUAGE_KEY", "")
LAMBDA_URL = os.environ.get("LAMBDA_FUNCTION_URL", "")


class Ticket(BaseModel):
    subject: str
    body: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/process-ticket")
def process_ticket(ticket: Ticket):
    """
    Orchestrates the full multi-cloud pipeline for one support ticket:
      1. Azure AI Language  -> extract key phrases (NLP)
      2. AWS Lambda+Bedrock -> draft a reply + recommend a KB doc
    """
    text = f"{ticket.subject}. {ticket.body}"

    try:
        key_phrases = extract_key_phrases(text)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Azure NLP step failed: {e}")

    try:
        lambda_data = call_aws_agent(text, key_phrases)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AWS agent step failed: {e}")

    return {
        "key_phrases": key_phrases,
        "draft_reply": lambda_data.get("draft_reply"),
        "recommended_doc": lambda_data.get("recommended_doc"),
    }


def extract_key_phrases(text: str) -> list[str]:
    url = f"{AZURE_ENDPOINT}language/:analyze-text?api-version=2023-04-01"
    headers = {
        "Ocp-Apim-Subscription-Key": AZURE_KEY,
        "Content-Type": "application/json",
    }
    body = {
        "kind": "KeyPhraseExtraction",
        "analysisInput": {"documents": [{"id": "1", "language": "en", "text": text}]},
    }
    resp = requests.post(url, headers=headers, json=body, timeout=15)
    resp.raise_for_status()
    result = resp.json()
    return result["results"]["documents"][0]["keyPhrases"]


def call_aws_agent(text: str, key_phrases: list[str]) -> dict:
    resp = requests.post(
        LAMBDA_URL,
        json={"ticket_text": text, "key_phrases": key_phrases},
        timeout=25,
    )
    resp.raise_for_status()
    return resp.json()
