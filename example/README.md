## Example

This all-in-one docker-compose file allows you to run a simple environment for development.

It can also help to show how you can deploy the bouncer using the haproxy docker image.

The docker-compose contains :

* haproxy
* nginx-server
* crowdsec

Host share docker unix with crowdsec container so it can read from nginx container stdout.
haproxy is configured to use haproxy-bouncer to query crowdsec.

## How to use 

It's already setup, you need to run 
```
docker-compose up -d
```

Then you have the containers up and running.