local redis = require "resty.redis"

-- Function to generate a simple math CAPTCHA
local function generate_captcha()
    local num1 = math.random(1, 10)
    local num2 = math.random(1, 10)
    local operation = math.random(1, 2)  -- 1 for addition, 2 for subtraction
    local question, answer

    if operation == 1 then
        question = string.format("What is %d + %d?", num1, num2)
        answer = num1 + num2
    else
        question = string.format("What is %d - %d?", math.max(num1, num2), math.min(num1, num2))
        answer = math.max(num1, num2) - math.min(num1, num2)
    end

    return question, tostring(answer)
end

-- Function to get the backend server IP for a given domain
local function get_backend_server(domain)
    -- local red = redis:new()
    -- local ok, err = red:connect("redis", 6379)
    -- if not ok then
    --     ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
    --     return nil
    -- end

    -- local ip, err = red:get(domain)
    -- if not ip then
    --     ngx.log(ngx.ERR, "Failed to get backend IP for domain ", domain, ": ", err)
    --     return nil
    -- end

    -- red:close()
    ip = "0.0.0.0"
    return ip
end

-- Main logic
if not ngx.var.cookie_captcha_verified then
    if ngx.var.request_method == "POST" and ngx.var.uri == "/verify_captcha" then
        -- Verify CAPTCHA
        ngx.req.read_body()
        local args, err = ngx.req.get_post_args()
        if not args then
            ngx.log(ngx.ERR, "Failed to get POST args: ", err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        local user_answer = args.answer
        local captcha_id = args.captcha_id

        local red = redis:new()
        local ok, err = red:connect("redis", 6379)
        if not ok then
            ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        local correct_answer, err = red:get("captcha:" .. captcha_id)
        if not correct_answer then
            ngx.log(ngx.ERR, "Failed to get CAPTCHA answer: ", err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        red:close()

        if user_answer == correct_answer then
            ngx.header["Set-Cookie"] = "captcha_verified=1; Path=/; HttpOnly; Secure; Max-Age=3600"
            return ngx.redirect(ngx.var.scheme .. "://" .. ngx.var.host .. ngx.var.request_uri)
        else
            ngx.status = ngx.HTTP_FORBIDDEN
            ngx.say("CAPTCHA verification failed. Please try again.")
            return ngx.exit(ngx.HTTP_FORBIDDEN)
        end
    else
        -- Generate and serve CAPTCHA
        local question, answer = generate_captcha()
        local captcha_id = ngx.md5(ngx.time() .. question)

        local red = redis:new()
        local ok, err = red:connect("redis", 6379)
        if not ok then
            ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        ok, err = red:set("captcha:" .. captcha_id, answer, "EX", 300)  -- Expire in 5 minutes
        if not ok then
            ngx.log(ngx.ERR, "Failed to set CAPTCHA answer: ", err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        red:close()

        ngx.header.content_type = "text/html"
        ngx.say(string.format([[
            <html>
            <body>
                <h1>Please solve the CAPTCHA</h1>
                <p>%s</p>
                <form method="POST" action="/verify_captcha">
                    <input type="hidden" name="captcha_id" value="%s">
                    <input type="text" name="answer" required>
                    <input type="submit" value="Verify">
                </form>
            </body>
            </html>
        ]], question, captcha_id))
        return ngx.exit(ngx.OK)
    end
else
    -- CAPTCHA is verified, proxy to backend server
    local backend_ip = get_backend_server(ngx.var.host)
    if backend_ip then
        ngx.var.backend_url = "http://" .. backend_ip
    else
        ngx.status = ngx.HTTP_BAD_GATEWAY
        ngx.say("Unable to resolve backend server")
        return ngx.exit(ngx.HTTP_BAD_GATEWAY)
    end
end