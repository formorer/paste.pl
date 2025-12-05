FROM perl:5.38

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libpq-dev python3-pygments postgresql-client \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY cpanfile cpanfile
RUN cpanm -n --installdeps .

COPY . .
ENV PASTE_CONFIG=/app/paste.conf

# Default runtime: start the app server
CMD ["morbo", "-l", "http://0.0.0.0:3000", "app.psgi"]

# If CMD_TEST is set, run tests instead (used in CI)
ENTRYPOINT ["/bin/sh", "-c", "if [ \"$CMD_TEST\" = \"1\" ]; then PASTE_CONFIG=${PASTE_CONFIG:-t/conf/paste.conf} prove -Ilib t; else exec \"$@\"; fi", "--"]
