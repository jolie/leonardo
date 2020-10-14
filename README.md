#  The Leonardo Web Server

This is Leonardo, a web server written in [Jolie](https://www.jolie-lang.org/).

You can use Leonardo as is, to host static files, or as a powerful server-generated pages framework.
The implementation of server-generated pages is left to the user, by using _hooks_ (defined as Jolie services). See [Fabrizio's website](https://github.com/fmontesi/website) for an example using templates and external services.

Leonardo uses plain HTTP for serving content. To add encryption (HTTPS), we recommend combining it with a reverse proxy (for example, we like [linuxserver/letsencrypt](https://hub.docker.com/r/linuxserver/letsencrypt/)).

# Start quickly with Docker for static content

If you have Docker installed and you just want to host some static content, using Leonardo is really quick.
First, pull the image from Docker Hub: `docker pull jolielang/leonardo`.
Assume that you have your static content in directory `myWWW` (replace this with your actual directory), then you can just run the following command and Leonardo will start.

```
docker run -it --rm -v "$(pwd)"/myWWW:/web -e LEONARDO_WWW=/web -p 8080:8080 jolielang/leonardo
```

Go ahead and browse [http://localhost:8080/](http://localhost:8080/).

# Static content

If you simply want to use Leonardo to host some static content, you can run it as it is.

You just have to tell Leonardo where the static content is located. You can do it in two ways:

- Pass the content directory as an argument. For example, if your content is in `/var/www`, then you should run the command `jolie launcher.ol /var/www`.
- Pass the content directory by using the environment variable `LEONARDO_WWW`. In this case, you just need to invoke `jolie launcher.ol`.

# Make a Docker image with your own website

Here is a Dockerfile that creates an image for a website whose content is stored in directory `myWWW`.

```
FROM jolielang/leonardo
ENV LEONARDO_WWW /web
COPY myWWW $LEONARDO_WWW
EXPOSE 8080
```
