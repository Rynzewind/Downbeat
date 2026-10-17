from pathlib import Path
import tempfile

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, HttpUrl

from .downloader import process
from .models import JobFormat, ProcessorRequest
from .workspace import job_workspace

app = FastAPI(title="Downbeat Processor", docs_url=None, redoc_url=None)


class ProcessBody(BaseModel):
    jobId: str
    sourceUrl: HttpUrl
    format: JobFormat
    callbackUrl: HttpUrl
    cookies: str | None = None


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/process")
def process_job(body: ProcessBody, authorization: str = Header(default="")):
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Processor credential required")
    request = ProcessorRequest(body.jobId, str(body.sourceUrl), body.format, str(body.callbackUrl), authorization[7:], body.cookies)
    with job_workspace(Path(tempfile.gettempdir()) / "downbeat", body.jobId) as workspace:
        artifact = process(request, workspace)
        return {"filename": artifact.filename, "contentType": artifact.content_type, "size": artifact.size}
