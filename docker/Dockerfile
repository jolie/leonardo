FROM alpine as Build

RUN apk update && \
		apk add git && \
		mkdir -p /var/lib/leonardo/www
RUN git clone --depth=1 https://github.com/jolie/leonardo.git /server/leonardo
RUN rm -rf /server/leonardo/docker
RUN rm -rf /server/leonardo/.git


# Start from scratch, copy leonardo
FROM jolielang/jolie
WORKDIR /
RUN mkdir -p /var/lib/leonardo/www
COPY server /

WORKDIR /server/leonardo

CMD ["jolie","leonardo.ol"]
