FROM alpine:latest
RUN apk add --no-cache bash curl
COPY ./parser.sh /app/parser.sh
RUN chmod +x /app/parser.sh
CMD ["/bin/bash", "/app/parser.sh"]
