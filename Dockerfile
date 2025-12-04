FROM perl:5.38

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libpq-dev python3-pygments postgresql-client \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY cpanfile cpanfile
RUN cpanm -n --installdeps .

COPY . .
ENV PASTE_CONFIG=/app/t/conf/paste.conf

CMD ["morbo", "-l", "http://0.0.0.0:3000", "app.psgi"]

# vim: syntax=Dockerfile
