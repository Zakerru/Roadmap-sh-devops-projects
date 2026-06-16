FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY ./site1.conf /etc/nginx/conf.d/
COPY ./site1/ /usr/share/nginx/html/
EXPOSE 80
