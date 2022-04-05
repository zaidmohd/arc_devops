## Test

export IngressIP='20.80.199.111'
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookbuyer
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore-v2
curl -v http://$IngressIP
kubectl -n bookbuyer logs bookbuyer-84dcd9c6dd-lcwpm bookbuyer -f | grep Identity:

curl -v -k --resolve ag.apps.dev.az.isaq.app:443:40.86.248.254 https://ag.apps.dev.az.isaq.app/

export IngressIP='52.184.241.97'
curl -v -k --resolve arcbox.k3sdevops.com:443:$IngressIP https://arcbox.k3sdevops.com/hello-arc
