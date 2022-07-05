FROM jolielang/jolie:edge

COPY . /leonardo
RUN rm -rf /leonardo/docker
RUN rm -rf /leonardo/.git

WORKDIR /leonardo
CMD ["jolie","launcher.ol"]
