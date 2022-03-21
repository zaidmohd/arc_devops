# arc_devops
export IngressIP='20.96.144.181'
curl -v -k --resolve hello.azurearc.com:$IngressIP https://hello.azurearc.com/bookstore
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookbyuer
curl -v -k --resolve hello.azurearc.com:443:$IngressIP https://hello.azurearc.com/bookstore
curl -v http://$IngressIP

kubectl -n bookbuyer logs bookbuyer-84dcd9c6dd-pfpjn bookbuyer -f | grep Identity: