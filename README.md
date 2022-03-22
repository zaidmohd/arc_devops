## Test

export IngressIP='52.167.190.81'
curl -v -k --resolve hello.azurearc.com:443$IngressIP https://hello.azurearc.com/bookstore
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookbyuer
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore
curl -v http://$IngressIP
kubectl -n bookbuyer logs bookbuyer-84dcd9c6dd-27kxw bookbuyer -f | grep Identity:
