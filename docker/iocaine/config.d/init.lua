local M = {}

print("!!! LUA SCRIPT LOADING !!!")

-- Helper to read file
local function read_file(path)
    -- Try iocaine.file first if available
    if iocaine and iocaine.file and iocaine.file.read_as_string then
        local content = iocaine.file.read_as_string(path)
        if content then return content end
    end
    -- Fallback to standard io
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content
    end
    return nil
end

-- 1. Load IP Blocklist
local ip_file = "/etc/iocaine/blocked_ips.txt"
local ip_prefixes = {}
local content = read_file(ip_file)
if content then
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^%d") then
            table.insert(ip_prefixes, line)
        end
    end
    print("Loaded " .. #ip_prefixes .. " IP prefixes from " .. ip_file)
else
    print("Failed to read " .. ip_file)
end
local IP_MATCHER = iocaine.matcher.IPPrefixes(unpack(ip_prefixes))

-- 2. Load AI Robots Blocklist
local robots_file = "/etc/iocaine/ai.robots.txt-robots.json"
local ai_agents = {}
-- We need JSON parsing. If iocaine.file.read_as_json isn't there, we might need a manual parse or regex hack for simple lists.
-- Assuming iocaine environment provides it as per docs.
local robots_data = nil
if iocaine and iocaine.file and iocaine.file.read_as_json then
    robots_data = iocaine.file.read_as_json(robots_file)
end

if robots_data then
    for _, item in ipairs(robots_data) do
        if item.agents then
            for _, agent in ipairs(item.agents) do
                table.insert(ai_agents, agent)
            end
        end
    end
    print("Loaded " .. #ai_agents .. " AI agents from " .. robots_file)
else
    print("Failed to read/parse " .. robots_file)
end

-- 3. Hardcoded SEO Bots
local seo_bots = {
    "DotBot", "Googlebot", "Bingbot", "Slurp", "DuckDuckBot", "Baiduspider", 
    "YandexBot", "Sogou", "Exabot", "facebot", "ia_archiver", "AhrefsBot", 
    "SemrushBot", "MJ12bot", "MegaIndex", "BLEXBot", "ZoomBot", "PetalBot",
    "Python", "aiohttp", "python-requests"
}

-- Combine all agents for the matcher
local all_agents = {}
for _, v in ipairs(ai_agents) do table.insert(all_agents, v) end
for _, v in ipairs(seo_bots) do table.insert(all_agents, v) end

local UA_MATCHER = iocaine.matcher.UserAgents(unpack(all_agents))

-- 4. Initialize Generators
local corpus_path = "/etc/iocaine/corpus/"
local MARKOV = iocaine.generator.Markov(
    corpus_path .. "1984.txt",
    corpus_path .. "brave-new-world.txt"
)
local WORDLIST = iocaine.generator.WordList(corpus_path .. "words.txt")

print("Lua handler initialized with custom corpus and blocklists.")

-- --- Decision Logic ---

function M.decide(request)
    local xff = request:header("x-forwarded-for")
    local ua = request:header("user-agent")
    
    -- Extract first IP from XFF
    local client_ip = xff:match("([^,]+)") or ""
    
    -- Check IP
    if client_ip ~= "" and IP_MATCHER:matches(client_ip) then
        print("BLOCKED IP: " .. client_ip .. " (UA: " .. ua .. ")")
        return "garbage"
    end
    
    -- Check UA
    if ua ~= "" and UA_MATCHER:matches(ua) then
        print("BLOCKED UA: " .. ua .. " (IP: " .. client_ip .. ")")
        return "garbage"
    end
    
    return nil -- Allow
end

-- --- Output Generation ---

function M.output(request, decision)
    local rng = iocaine.generator.Rng:from_request(request, "default")
    
    local response = iocaine.Response()
    response.status = 200
    
    -- Generate some nice Markov garbage
    local body = ""
    for i = 1, rng:in_range(3, 8) do
        body = body .. "<p>" .. MARKOV:generate(rng, rng:in_range(20, 100)) .. "</p>\n"
        -- Add a random link to keep them busy
        local link_text = WORDLIST:generate(rng, rng:in_range(1, 2), " ")
        local link_url = "/" .. WORDLIST:generate(rng, rng:in_range(1, 3), "/")
        body = body .. "<p><a href=\"" .. link_url .. "\">" .. link_text .. "</a></p>\n"
    end
    
    response.body = "<html><body>\n" .. body .. "</body></html>"
    response:set_header("content-type", "text/html")
    
    return response
end

return M
