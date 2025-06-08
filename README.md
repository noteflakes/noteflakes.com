# noteflakes.com

This repository contains the source code for [noteflakes.com](https://noteflakes.com).

### Tools used

- [Impression](https://github.com/digital-fabric/impression)
- [Papercraft](https://github.com/digital-fabric/papercraft)
- [TP2](https://github.com/noteflakes/tp2)
- [UringMachine](https://github.com/digital-fabric/uringmachine)

### How to run

```bash
# install dependencies
$ bundle install

# run server
$ bundle exec tp2 app.rb

# run dockerized server with caddy as reverse proxy
docker compose up
```
