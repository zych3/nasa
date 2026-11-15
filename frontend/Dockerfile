# Flutter web frontend, served by nginx.
#
# Build (from the repo root):
#   docker build -t fieldshift-frontend frontend
#   docker build -t fieldshift-frontend --build-arg API_BASE_URL=http://my-server:5066 frontend
#
# API_BASE_URL is the backend address as seen from the user's browser, not from inside Docker.

FROM debian:bookworm-slim AS build
ARG FLUTTER_VERSION=3.50.0
RUN apt-get update     && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates     && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch $FLUTTER_VERSION https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:$PATH"
RUN flutter config --no-analytics && flutter precache --web
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
ARG API_BASE_URL=http://localhost:5066
# true = show the "test sign-in" button (the backend needs Accounts:TestLogin).
ARG TEST_LOGIN=false
RUN flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL --dart-define=TEST_LOGIN=$TEST_LOGIN

FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
