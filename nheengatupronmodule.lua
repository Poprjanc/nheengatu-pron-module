local export = {}
local languages_module = "Module:languages"
local pron_utilities_module = "Module:pron utilities"
local m_str_utils = require("Module:string utilities")

local lower = m_str_utils.lower
local rfind = m_str_utils.find
local rsubn = m_str_utils.gsub
local lang = require(languages_module).getByCode("yrl")

local function format_prons(...)
	return require(pron_utilities_module).format_prons(...)
end

local primary_stress = "ˈ"
local secondary_stress = "ˌ"

local single_char_subs = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u",
	["ã"] = "ã", ["ẽ"] = "ẽ", ["ĩ"] = "ĩ", ["õ"] = "õ", ["ũ"] = "ũ",
	["î"] = "ɨ", 	["x"] = "ʃ", ["y"] = "j", ["w"] = "w", ["'"] = "ʔ",
	["g"] = "ɡ", ["z"] = "z", ["j"] = "ʒ", ["r"] = "ɾ", 	["-"] = ""
}

-- Map digraphs (handling mb with superscript bilabial nasal, and nd/ng as nasalization triggers)
local digraph_to_temp = {
	["mb"] = "ᵐb",
	["nd"] = "nd",
	["ng"] = "ⁿɡ",
	["kw"] = "kʷ",
	["gw"] = "ɡʷ",
	["nh"] = "ɲ",
	["rr"] = "r",
}

local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- Added î and ɨ to the vowel groups
local V = "[aáeéiíoóuúãẽĩõũɛɔîɨ]"
local V_written = "[aáeéiíoóuúãẽĩõũî]"
local C = "[^aáeéiíoóuúãẽĩõũɛɔîɨˈˌ%.]"

local function syllabify(text)
	-- Insert dot between adjacent vowels (Hiatus)
	for i = 1, 2 do
		text = rsub(text, "(" .. V .. ")(" .. V .. ")", "%1.%2")
	end
	
	-- Insert dot between V and C+V
	for i = 1, 3 do
		text = rsub(text, "(" .. V .. ")(" .. C .. "+" .. V .. ")", "%1.%2")
	end
	
	-- Insert dot between VC and C+V (for internal clusters)
	for i = 1, 3 do
		text = rsub(text, "(" .. V .. C .. ")(" .. C .. "+" .. V .. ")", "%1.%2")
	end
	
	return text
end

-- Pass dialect_code down to determine if dialect-specific rules apply
local function process_base_word(word, is_compound_part, dialect_code)
	-- Handle Portuguese loanword exceptions BEFORE any phonology steps
	if word == "mas" then
		word = "ma"
	elseif word == "só" then
		word = "ˈsɔ"
	end

	-- Identify phonetic monosyllables that skip phonological reduplication
	local non_reduplicating = {["te"] = true, ["ba"] = true, ["ba'"] = true, ["ma"] = true, ["ˈsɔ"] = true} 
	local is_exception = non_reduplicating[word]
	
	local is_rn_dialect = (dialect_code == "rn" or dialect_code == "sgc" or dialect_code == "sir")

	-- STEP 0: Rio Negro Dialect Pre-processing	
	-- 0a. Moraic Expansion for Monosyllables (Minimal Foot)
	-- Only occurs in Rio Negro and its sub-dialects
	if is_rn_dialect and not is_exception and not is_compound_part then
		local _, vowel_count = rsubn(word, V_written, "")
		
		if vowel_count == 1 then
			word = rsub(word, "(" .. V_written .. ")", function(v)
				local unaccent_map = {["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u"}
				local first_v = unaccent_map[v] or v
				return first_v .. "ʔ" .. v
			end)
		end
	end

	-- 0b. Diphthongize word-final i and u
	word = rsub(word, "(" .. V_written .. ")i$", "%1y")
	word = rsub(word, "(" .. V_written .. ")u$", "%1w")

	-- 0c. Haplology: Reduce identical vowels
	word = rsub(word, "(" .. V_written .. ")%1", "%1")
	word = rsub(word, "íi", "í")
	word = rsub(word, "úu", "ú")
	word = rsub(word, "áa", "á")
	
	-- 0d. Intrusive Glides (Hiatus Breaking)
	word = rsub(word, "([uúũ])([aáeéiíoóãẽĩõɛɔî])", "%1w%2")
	word = rsub(word, "([iíĩ])([aáeóuúõũãẽɛɔî])", "%1y%2")

	-- 1. Nasalization rule for nd, ng, and nt
	word = rsub(word, "([aeiouáéíóúî])nd", function(v)
		local nasal_map = {["a"]="ã", ["á"]="ã", ["e"]="ẽ", ["é"]="ẽ", ["i"]="ĩ", ["í"]="ĩ", ["o"]="õ", ["ó"]="õ", ["u"]="ũ", ["ú"]="ũ"}
		return (nasal_map[v] or v) .. "d"
	end)
		
	word = rsub(word, "([aeiouáéíóúî])ng", function(v)
		local nasal_map = {["a"]="ã", ["á"]="ã", ["e"]="ẽ", ["é"]="ẽ", ["i"]="ĩ", ["í"]="ĩ", ["o"]="õ", ["ó"]="õ", ["u"]="ũ", ["ú"]="ũ"}
		return (nasal_map[v] or v) .. "ɡ"
	end)

	-- Nasalize vowels before 'nt' and reduce to 't'
	word = rsub(word, "([aeiouáéíóúî])nt", function(v)
		local nasal_map = {["a"]="ã", ["á"]="ã", ["e"]="ẽ", ["é"]="ẽ", ["i"]="ĩ", ["í"]="ĩ", ["o"]="õ", ["ó"]="õ", ["u"]="ũ", ["ú"]="ũ"}
		return (nasal_map[v] or v) .. "t"
	end)

	-- 2. Map other digraphs
	for digraph, temp in pairs(digraph_to_temp) do
		word = rsub(word, digraph, temp)
	end
	
	-- 3. Dialectal Palatalization
	-- In Amazon and Solimões dialects, 't' palatalizes to [t͡ʃ] before 'i', 'í', or 'ĩ'
	if not is_rn_dialect then
		word = rsub(word, "t([iíĩ])", "t͡ʃ%1")
	end
	
	-- In Solimões dialect only, 'd' palatalizes to [d͡ʒ] before 'i', 'í', or 'ĩ'
	if dialect_code == "sl" then
		word = rsub(word, "d([iíĩ])", "d͡ʒ%1")
	end
		
	-- 4. Explicit stress assignment (Acute vs. Tilde)
	if rfind(word, "[áéíóú]") then
		word = rsub(word, "(" .. C .. "*[áéíóú])", primary_stress .. "%1")
	elseif rfind(word, "[ãẽĩõũ]") then
		word = rsub(word, "(" .. C .. "*[ãẽĩõũ]" .. C .. "*)$", primary_stress .. "%1")
	end
		
	-- 5. Replace single characters and strip accents for pure IPA
	word = rsub(word, ".", single_char_subs)
		
	-- 6. Fallback stress if no stress mark exists
	if not rfind(word, primary_stress) then
		if rfind(word, "[wy]$") then
			word = rsub(word, "(" .. C .. "*" .. V .. "+[wy])$", primary_stress .. "%1")
		elseif rfind(word, V .. ".*" .. V) then
			word = rsub(word, "(" .. C .. "*" .. V .. "+" .. C .. "*" .. V .. "+" .. C .. "*)$", primary_stress .. "%1")
		else
			word = rsub(word, "(" .. C .. "*" .. V .. "+" .. C .. "*)$", primary_stress .. "%1")
		end
	end

	-- 6.2. Shift stress mark past coda glides (j/w) to keep them in the preceding syllable
	word = rsub(word, "([ˈˌ])([jw])(" .. C .. ")", "%2%1%3")

	-- 6.5. Open 'e' to 'ɛ' in stressed syllables
	word = rsub(word, "([ˈˌ]" .. C .. "*)e", "%1ɛ")
		
	-- 7. Syllabification
	word = syllabify(word)
		
	return word
end

local function process_word(word, dialect_code)
	-- Case A: Plural suffix -itá / -ita (attaches with a dot)
	local base, plural = rsubn(word, "%-i[tT][áa]$", "")
	if plural > 0 then
		local processed_base = process_base_word(base, true, dialect_code)
		processed_base = rsub(processed_base, primary_stress, secondary_stress)
		return processed_base .. ".i" .. primary_stress .. "ta"
	end
	
	-- Case B: General compound words containing hyphens (combines with a dot in IPA)
	if rfind(word, "%-%a") then
		local parts = mw.text.split(word, "%-")
		local processed_parts = {}
		for i, part in ipairs(parts) do
			local p = process_base_word(part, true, dialect_code)
			if i < #parts then
				p = rsub(p, primary_stress, secondary_stress)
			end
			table.insert(processed_parts, p)
		end
		
		local result = table.concat(processed_parts, ".")
		-- Remove redundant syllable dot right before a stress mark (e.g., .ˈpu -> ˈpu)
		result = rsub(result, "%.([ˈˌ])", "%1")
		return result
	end
	
	-- Case C: Standard single word
	return process_base_word(word, false, dialect_code)
end

function export.toIPA(text, dialect_code)
	-- Default to Rio Negro if called externally without a specific dialect
	dialect_code = dialect_code or "rn"
	
	text = lower(text)
	text = rsub(text, "^%s*(.-)%s*$", "%1") -- Trim outer spaces
	
	local words = mw.text.split(text, " ")
	local ipa_words = {}
	
	for _, word in ipairs(words) do
		table.insert(ipa_words, process_word(word, dialect_code))
	end
	
	return table.concat(ipa_words, " ")
end

-- Extracts the rhyme based on the stressed vowel to the end of the word
local function extract_rhyme(ipa)
	local last_word = mw.ustring.match(ipa, "%S+$") or ipa
	local stressed = mw.ustring.match(last_word, "ˈ(.*)")
	if not stressed then return nil end
	
	-- Match from the first IPA vowel (skipping onset consonants) and capture to the end
	local rhyme = mw.ustring.match(stressed, "^[^aeiouãẽĩõũɛɔɨ]*([aeiouãẽĩõũɛɔɨ].*)")
	if rhyme then
		-- Remove syllable dots and secondary stress marks
		return rsub(rhyme, "[%.ˌ]", "")
	end
	return nil
end

function export.IPA(frame)
	local parent_args = frame:getParent().args
	
	local has_plus = false
	local has_any_dialect = false
	local base_args = {}
	local base_i = 1
	
	-- Known dialect codes from the hierarchy
	local known_dialects = {
		rn = true, sgc = true, sir = true, 
		am = true, aam = true, mam = true, bam = true, 
		sl = true
	}
	
	-- 1. Parse parent arguments to separate the '+' sign, base words, and specific dialects
	for k, v in pairs(parent_args) do
		if type(k) == "number" then
			if v == "+" then
				has_plus = true
			else
				base_args[base_i] = v
				base_i = base_i + 1
			end
		elseif type(k) == "string" and known_dialects[k] then
			if v and v ~= "" then
				has_any_dialect = true
			end
		end
	end
	
	-- 2. Determine if Rio Negro should be included
	local include_rn = false
	if parent_args["rn"] or has_plus or not has_any_dialect then
		include_rn = true
	end

	-- 3. Define the dialect hierarchy and their specific Wikipedia links
	local dialects_config = {
		{code = "rn",  name = "[[w:Rio Negro (Amazon)|Rio Negro]]", level = 1},
		{code = "sgc", name = "[[w:São Gabriel da Cachoeira|São Gabriel da Cachoeira]]", level = 2},
		{code = "sir", name = "[[w:Santa Isabel do Rio Negro|Santa Isabel do Rio Negro]]", level = 2},
		{code = "am",  name = "[[w:Amazon River|Amazon]]", level = 1},
		{code = "aam", name = "[[w:Amazon River|Upper Amazon]]", level = 2},
		{code = "mam", name = "[[w:Amazon River|Middle Amazon]]", level = 2},
		{code = "bam", name = "[[w:Amazon River|Lower Amazon]]", level = 2},
		{code = "sl",  name = "[[w:Solimões River|Solimões]]", level = 1},
	}

	local results = {}
	local first_item = true
	
	local rhymes_list = {}
	local seen_rhymes = {}
	
	-- 4. Iterate through the dialects and format the active ones
	for _, dialect in ipairs(dialects_config) do
		local is_active = false
		local explicit_val = parent_args[dialect.code]
		
		-- Check if this specific dialect should be generated
		if dialect.code == "rn" and include_rn then
			is_active = true
		elseif explicit_val and explicit_val ~= "" then
			is_active = true
		end
		
		if is_active then
			local fake_args = { ["a"] = dialect.name }
			
			-- If a specific word was given (and it isn't just a + sign), use it
			if explicit_val and explicit_val ~= "+" and explicit_val ~= "" then
				fake_args[1] = explicit_val
			else
				-- Otherwise, fallback to the base default word(s) provided
				for i, v in ipairs(base_args) do
					fake_args[i] = v
				end
			end
			
			-- Capture the current dialect to pass into respelling_to_IPA
			local current_dialect_code = dialect.code
			
			local function respelling_to_IPA(data)
				local IPA = export.toIPA(data.respelling or data.pagename, current_dialect_code)
				
				-- Extract the rhyme structure dynamically while producing IPA
				local rhyme = extract_rhyme(IPA)
				if rhyme and not seen_rhymes[rhyme] then
					seen_rhymes[rhyme] = true
					table.insert(rhymes_list, { rhyme = rhyme })
				end
				
				return "[" .. IPA .. "]"
			end
			
			local formatted = format_prons{
				lang = lang,
				respelling_to_IPA = respelling_to_IPA,
				raw_args = fake_args,
				track_module = "yrl-pronunciation",
			}
			
			-- Remove any stray bullets format_prons might generate natively
			formatted = string.gsub(formatted, "^%s*%*+%s*", "")
			
			-- The first item borrows the asterisk from the wiki page. 
			-- Subsequent items need asterisks injected directly.
			if first_item then
				table.insert(results, formatted)
				first_item = false
			else
				local prefix = (dialect.level == 2) and "** " or "* "
				table.insert(results, prefix .. formatted)
			end
		end
	end
	
	-- 5. Append formatted rhymes using Wiktionary's standard Module:rhymes
	if #rhymes_list > 0 then
		local formatted_rhymes = require("Module:rhymes").format_rhymes({ lang = lang, rhymes = rhymes_list })
		table.insert(results, "* " .. formatted_rhymes)
	end
	
	-- Return all generated lines concatenated with line breaks
	return table.concat(results, "\n")
end

return export
