FROM python:2-alpine3.9
RUN apk update && apk add bash
ADD transaction-generator.py .
RUN pip install requests
CMD python transaction-generator.py
