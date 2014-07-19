json.array!(@proxies) do |proxy|
  json.extract! proxy, :id, :ip, :port, :username, :password, :status
  json.url proxy_url(proxy, format: :json)
end
