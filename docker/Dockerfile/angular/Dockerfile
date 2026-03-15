FROM node:16-alpine as build-stage
WORKDIR /app
COPY package.json .
COPY . .
RUN rm yarn.lock
RUN rm -rf node_modules
RUN npm i
#RUN npm run build
FROM nginx:latest
RUN mkdir /app
#COPY --from=build-stage /app/www/ /usr/share/nginx/html
COPY --from=build-stage /app/ /usr/share/nginx/html
COPY .host/front-host/nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
