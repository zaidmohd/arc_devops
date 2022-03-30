## Test

export IngressIP='20.124.174.34'
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookbuyer
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore-v2
curl -v http://$IngressIP
kubectl -n bookbuyer logs bookbuyer-84dcd9c6dd-lcwpm bookbuyer -f | grep Identity:
