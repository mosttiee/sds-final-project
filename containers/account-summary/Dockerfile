FROM node:8-alpine3.9

WORKDIR /app

#RUN apk update && apk add bash
#RUN npm install -g nodemon
ADD package.json /app/package.json
RUN npm config set registry http://registry.npmjs.org
RUN npm install && npm ls
RUN mv /app/node_modules /node_modules

ADD . /app

EXPOSE 80
ENV PORT 80

CMD ["node", "server.js"]
