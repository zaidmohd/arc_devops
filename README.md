## Test

export IngressIP='20.75.14.254'
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookbyuer
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore
curl -v http://$IngressIP
kubectl -n bookbuyer logs bookbuyer-84dcd9c6dd-27kxw bookbuyer -f | grep Identity:
