# This script ensures that all Bower dependencies are checked against a whitelist of commits.
# Only non-minified source if checked, so always make sure to minify dependencies yourself. Development
# tools - and perhaps some very large common libraties - are skipped in these checks.

# Ruby is needed as well as the following gems:
# gem install json

# Github API requires authentication because of rate limiting. So run with:
# GITHUB_USER=username GITHUB_TOKEN=personal_access_token ruby check-dependencies.rb

require 'json'
require 'open-uri'

whitelist = JSON.parse(File.read('dependency-whitelist.json'))

@failed = false

##########
# Common #
##########

def first_two_digits_match(a, b)
  # e.g. "1.1.x" and "1.1.3" matches
  #      "1.1.x" and "1.2.0" does not match

  a.split(".")[0].to_i == b.split(".")[0].to_i && a.split(".")[1].to_i == b.split(".")[1].to_i
end


def getJSONfromURL(url)
  if ENV['GITHUB_USER'] and ENV['GITHUB_TOKEN']
    http_options = {:http_basic_authentication=>[ENV['GITHUB_USER'], ENV['GITHUB_TOKEN']]}
    json = JSON.load(open(url, http_options))
  else
    json = JSON.load(open(url))
  end
  return json
end
# apply_math = lambda do |auth, , nom|
#   a.send(fn, b)
# end

# add = apply_math.curry.(:+)
# subtract = apply_math.curry.(:-)
# multiply = apply_math.curry.(:*)
# divide = apply_math.curry.(:/)

def set_dep(requested_version, whitelisted_repo_key, sha)
  if requested_version.include?("git+ssh") # Preserve URL
    return "#{ requested_version.split("#").first }##{ sha }"
  else
    return "#{ whitelisted_repo_key }##{ sha }"
  end
end

def check_commits!(deps, whitelist, output_deps, type)
  deps.keys.each do |key|
    if whitelist["ignore"].include? key # Skip check
      # unless ["angular", "angular-mocks", "angular-animate", "angular-bootstrap", "angular-cookies", "angular-sanitize", "angular-translate-loader-static-files","bootstrap-sass"].include? key   # Skip package altoghether
      #   output_deps.delete(key)
      # end
      next
    end

    dep = deps[key]

    if whitelist["pgp-signed"].include?(key)
      # The following pakcages are not checked against a commit whistelist,
      # but rather they need to be signed by someone with the right GPG key.
      # This is checked in a later Grunt task
      next
    elsif whitelist[key]
      # For Bower it expects a version formatted like "1.2.3" or "1.2.x". It will use the highest match exact version.
      requested_version = dep

      requested_version = requested_version.split("#").last # e.g. "pernas/angular-password-entropy#0.1.3" -> "0.1.3"

      requested_digits = requested_version.split(".")

      if requested_version[0] == "~" || requested_digits.length != 3 || requested_digits[2] == "x"
        puts "Version format not supported: #{ key } #{ requested_version }"
        @failed = true
      elsif requested_digits[2] != "*" && requested_version == whitelist[key]['version'] # Exact match
      elsif requested_digits[2] == "*" and first_two_digits_match(requested_version, whitelist[key]['version'])
      else
        # https://github.com/weilu/bip39/compare/2.1.0...2.1.2
        url = "https://github.com/#{ whitelist[key]["repo"] }/compare/#{ whitelist[key]['version'] }...#{ requested_version }"
        puts "#{ key } version #{ requested_version } has not been whitelisted yet. Most recent: #{ whitelist[key]['version'] }. Difference: \n" + url
        @failed = true
        next
      end

      url = "https://api.github.com/repos/#{ whitelist[key]["repo"] }/tags"
      # puts url
      tags = getJSONfromURL(url)

      tag = nil

      tags.each do |candidate|
        if candidate["name"] == "v#{ requested_version }" || candidate["name"] == requested_version
          tag = candidate
          break
        elsif requested_digits[2] == "*" && first_two_digits_match(requested_version, candidate["name"])
          if whitelist[key]["version"] < candidate["name"].gsub("v","")
            puts "Warning: a more recent version #{ candidate["name"] } is available for #{ key }"
          else
            tag = candidate
            break
          end


        end
      end

      if !tag.nil?
        # Check if tagged commit matches whitelist commit (this or earlier version)
        if whitelist[key]["commits"].include?(tag["commit"]["sha"])
          output_deps[key] = set_dep(dep, whitelist[key]["repo"], tag["commit"]["sha"])
        else
          puts "Error: v#{ dep['version'] } of #{ key } does not match the whitelist."
          @failed = true
          next
        end


      else
        puts "Warn: no Github tag found for v#{ dep['version'] } of #{ key }."
        # Look through the list of commits instead:

        url = "https://api.github.com/repos/#{ whitelist[key]["repo"] }/commits"
        # puts url
        commits = getJSONfromURL(url)
        commit = nil

        commits.each do |candidate|
          if candidate["sha"] == whitelist[key]['commits'].first
            commit = candidate

            break
          end
        end

        if !commit.nil?
          output_deps[key] = set_dep(dep, whitelist[key]["repo"], commit["sha"])
        else
          throw "Error: no Github commit #{ whitelist[key]["commits"].first } of #{ key }."
          next
        end
      end
    else
      puts "#{key} not whitelisted!"
      @failed = true
    end
  end
end

package = JSON.parse(File.read('package.json'))

#########
# Bower #
#########
# Only used by the frontend
if package["name"] == "angular-blockchain-wallet"
  bower = JSON.parse(File.read('bower.json'))
  output = bower.dup
  output.delete("authors")
  output.delete("main")
  output.delete("ignore")
  output.delete("pgp-signed")
  output.delete("pgp-keys")
  output.delete("license")
  output.delete("keywords")

  deps = bower["dependencies"]

  check_commits!(deps, whitelist, output["dependencies"], :bower)

  File.write("build/bower.json", JSON.pretty_generate(output))
end

if @failed
  abort "Please fix the above issues..."
end
