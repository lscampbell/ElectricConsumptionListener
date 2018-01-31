FROM stcenergy/ruby-24-alpine:0.0.4
COPY . /app/
WORKDIR /app
RUN cd /app/ && bundle install --without development test