FROM arm32v6/openjdk:8-jdk-alpine
COPY . /app
WORKDIR /app
RUN apk update && apk add bash
RUN apk update && apk add mysql mysql-client
ENTRYPOINT ["/app/custom-entrypoint.sh"]
CMD java -jar target/*.jar
