FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY ./site.conf /etc/nginx/conf.d/
COPY ./static/ /usr/share/nginx/html/
EXPOSE 80
