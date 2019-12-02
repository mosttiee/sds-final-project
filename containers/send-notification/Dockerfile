FROM arm32v6/openjdk:8-jdk-alpine
RUN apk update && apk add bash
COPY . /app
WORKDIR /app
CMD java -jar target/*.jar


