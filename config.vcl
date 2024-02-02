vcl 4.1;

# Imports
import std;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "135.148.103.238"; # UPDATE this only if the web server is not on the same machine
    .port = "80";      # UPDATE 8080 with your web server's (internal) port
}
backend cleaneats {
  .host = "135.148.94.242";
  .port = "80";
  .host_header = "testing.beastcoastnutrition.com";
}

sub vcl_recv {
    if (req.http.host ~ "^(testing\.)?beastcoastnutrition.com\.com$") {
        set req.http.host = "testing.beastcoastnutrition.com";
        set req.backend_hint = cleaneats;
    }

    if (req.http.host ~ "^(www\.)?cleaneatsmeal.prep\.com$") {
        set req.http.host = "www.cleaneatsmealprep.com";
        set req.backend_hint = cleaneats;
    }

    if (req.url ~ "^/\.well-known/acme-challenge/") {
        return (pass);
    }

    if (req.restarts == 0) {
        if (req.http.X-Real-IP) {
            set req.http.X-Forwarded-For = req.http.X-Real-IP;
        } else if (req.http.X-Forwarded-For) {
            set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    unset req.http.proxy;

    if (req.url !~ "wp-admin") {
        set req.url = std.querysort(req.url);
    }

    if (
        req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE"
    ) {
        return (pipe);
    }

    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    if (req.http.X-Requested-With == "XMLHttpRequest" || req.url ~ "nocache") {
        return (pass);
    }

    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|jpeg|png|gif|gz|tgz|bz2|tbz|mp3|ogg|swf)$") {
            unset req.http.Accept-Encoding;
        } elseif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elseif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            unset req.http.Accept-Encoding;
        }
    }

    if (req.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        unset req.http.Cookie;
        return (hash);
    }

    return (hash);
}

sub vcl_backend_response {
    if (
        beresp.status == 500 ||
        beresp.status == 502 ||
        beresp.status == 503 ||
        beresp.status == 504
    ) {
        return (abandon);
    }

    if (
        bereq.url ~ "^/addons" ||
        bereq.url ~ "^/administrator" ||
        bereq.url ~ "^/cart" ||
        bereq.url ~ "^/checkout" ||
        bereq.url ~ "^/component/banners" ||
        bereq.url ~ "^/component/socialconnect" ||
        bereq.url ~ "^/component/users" ||
        bereq.url ~ "^/connect" ||
        bereq.url ~ "^/contact" ||
        bereq.url ~ "^/login" ||
        bereq.url ~ "^/logout" ||
        bereq.url ~ "^/lost-password" ||
        bereq.url ~ "^/my-account" ||
        bereq.url ~ "^/register" ||
        bereq.url ~ "^/signin" ||
        bereq.url ~ "^/signup" ||
        bereq.url ~ "^/wc-api" ||
        bereq.url ~ "^/wp-admin" ||
        bereq.url ~ "^/wp-login.php" ||
        bereq.url ~ "^\?add-to-cart=" ||
        bereq.url ~ "^\?wc-api="
    ) {
        set beresp.uncacheable = true;
        return (deliver);
    }

    if (
        bereq.http.Authorization ||
        bereq.http.Authenticate ||
        bereq.http.X-Logged-In == "True" ||
        bereq.http.Cookie ~ "userID" ||
        bereq.http.Cookie ~ "joomla_[a-zA-Z0-9_]+" ||
        bereq.http.Cookie ~ "(wordpress_[a-zA-Z0-9_]+|wp-postpass|comment_author_[a-zA-Z0-9_]+|woocommerce_cart_hash|woocommerce_items_in_cart|wp_woocommerce_session_[a-zA-Z0-9]+)"
    ) {
        set beresp.uncacheable = true;
        return (deliver);
    }

    if (beresp.http.X-Requested-With == "XMLHttpRequest" || bereq.url ~ "nocache") {
        set beresp.uncacheable = true;
        return (deliver);
    }

    if (bereq.method == "POST") {
        set beresp.uncacheable = true;
        return (deliver);
    }

    if (beresp.http.X-Logged-In == "False" && bereq.method != "POST") {
        unset beresp.http.Set-Cookie;
    }

    unset beresp.http.Pragma;
    unset beresp.http.Vary;
    unset beresp.http.etag;

    set beresp.grace = 24h;

    if (beresp.http.Cache-Control !~ "max-age" || beresp.http.Cache-Control ~ "max-age=0") {
        set beresp.http.Cache-Control = "public, max-age=180, stale-while-revalidate=360, stale-if-error=43200";
    }

    if (bereq.url ~ "^[^?]*\.(7z|avi|bmp|bz2|css|csv|doc|docx|eot|flac|flv|gif|gz|ico|jpeg|jpg|js|less|mka|mkv|mov|mp3|mp4|mpeg|mpg|odt|ogg|ogm|opus|otf|pdf|png|ppt|pptx|rar|rtf|svg|svgz|swf|tar|tbz|tgz|ttf|txt|txz|wav|webm|webp|woff|woff2|xls|xlsx|xml|xz|zip)(\?.*)?$") {
        unset beresp.http.set-cookie;
        set beresp.do_stream = true;
    }

    return (deliver);
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }

    return (deliver);
}