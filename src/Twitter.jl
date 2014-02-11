module Twitter

#############################################################
#
# Imports & Exports
#
#############################################################

import AWS.Crypto.hmacsha1_digest
using Codecs, HttpCommon, Requests, JSON

export twitterauth, 						#Authentication function
	   twittercred, 						#Authentication object
	   twgetappauth,						#GET helper function for application_only endpoints
	   get_user_timeline,					#public API function
	   search_tweets,						#public API function
	   get_friends_ids,						#public API function
	   get_followers_ids,					#public API function
	   get_friends_list,					#public API function
	   get_followers_list,					#public API function
	   get_help_configuration,				#public API function
	   get_help_privacy,					#public API function
	   get_help_tos,						#public API function
	   get_application_rate_limit_status,	#public API function
	   get_help_languages,					#public API function
	   oauth_header, 						#Helper function
	   post_status_update   				#public API function

#External files by API section
include("help.jl")
include("spam.jl")

#############################################################
#
# Custom Types
#
#############################################################

#Type to hold Twitter API credentials
type TWCRED
    consumer_key::ASCIIString
    consumer_secret::ASCIIString
    auth_only_bearer_token::ASCIIString
    oauth_token::ASCIIString
    oauth_secret::ASCIIString
end

#Need parser type for Tweets data type
#Need parser type for id data type

#############################################################
#
# General Functions
#
#############################################################

#Function that builds global variable to hold authentication keys
function twitterauth(consumer_key::ASCIIString, consumer_secret::ASCIIString; oauth_token::ASCIIString="", oauth_secret::ASCIIString="")
    #Create a global variable to hold return from this function
    global twittercred
    
    #Do application_only authentication
    #https://dev.twitter.com/docs/auth/application-only-auth
        
        #Build authentication string values
        concat_consumer = "$(encodeURI(consumer_key)):$(encodeURI(consumer_secret))"
        auth_header_value = base64(concat_consumer)
    
        #Call Twitter API to get bearer token
        response = post(URI("https://api.twitter.com/oauth2/token"),
                            "grant_type=client_credentials",
                            {"Authorization" => "Basic $auth_header_value",
                             "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8"})
        
    #If successful, convert data into Dict to get token, return TWCRED
        if response.status == 200
            response_dict = JSON.parse(response.data)
            
            #Per Twitter docs, validate token_type as "bearer"
            if response_dict["token_type"] == "bearer"
                return twittercred = TWCRED(consumer_key,
                                            consumer_secret,
                                            response_dict["access_token"],
                                            oauth_token,
                                            oauth_secret)
            else
                error("API returned success, but didn't return 'bearer' token type. Error unknown, try again.")
            end
        else
            error("Authentication failed. Please validate your consumer_key & consumer_secret and try again.")
        end
    
    #TODO: Figure out how to do OAuth authentication directly, rather than user putting in credentials directly
end

#General function to handle all Twitter GET requests that can be handled by application_only authentication
#Each function call will have one required argument whose value gets passed through
function twgetappauth(endpoint, defaultarg, defaultval, options)
    #Uses function from Requests to create query string from Dict
    query_string = "$(Requests.format_query_str(options))"
    
    #URIencode for strings as defensive maneuver
    defaultval = encodeURI(defaultval)

	response = get(URI("$(endpoint)?$defaultarg=$defaultval$query_string");
                   headers = {"Authorization" => "Bearer $(Twitter.twittercred.auth_only_bearer_token)"})
    return response
end

#Use this function to build the header for every OAuth call
function oauth_header(httpmethod::String, baseurl::String, options::Dict)                
    
    #Format non-parameter strings
    baseurl = encodeURI(baseurl)
    httpmethod = encodeURI(uppercase(httpmethod))
    oauth_consumer_secret = encodeURI(twittercred.consumer_secret)
    oauth_token_secret = encodeURI(twittercred.oauth_secret)
    
    #URI encode values for all keys passed in on options
    for (k, v) in options
        options["$(k)"] = encodeURI(v)
    end
    
    #keys for parameter string
    options["oauth_consumer_key"] = encodeURI(twittercred.consumer_key)
    options["oauth_nonce"] = encodeURI(randstring(32)) #32 random alphanumeric characters
    options["oauth_signature_method"] = "HMAC-SHA1"
    options["oauth_timestamp"] = @sprintf("%.0f", time()) #timestamp in seconds
    options["oauth_token"] = encodeURI(twittercred.oauth_token)
    options["oauth_version"] = "1.0"
    
    #Get all available keys, sort them
    optionskeys = collect(keys(options))
    sort!(optionskeys)

    #parameter_string
    #Inspired by Requests.format_query_string
    query_str = ""
    for k in optionskeys
        v = options["$(k)"] #get value for ordered key
        query_str *= "$k=$v&"
    end
    query_str = chop(query_str) # remove the trailing &
    
    parameter_string = encodeURI(query_str) 
    
    #signature_base_string
    signature_base_string = "$(httpmethod)&$(baseurl)&$(parameter_string)"
    
    #Signing key
    signing_key = "$(oauth_consumer_secret)&$(oauth_token_secret)"
    
    #Calculate signature
    oauth_sig = encodeURI(base64(hmacsha1_digest(signature_base_string, signing_key)))
    
    return "OAuth oauth_consumer_key=\"$(options["oauth_consumer_key"])\", oauth_nonce=\"$(options["oauth_nonce"])\", oauth_signature=\"$(oauth_sig)\", oauth_signature_method=\"$(options["oauth_signature_method"])\", oauth_timestamp=\"$(options["oauth_timestamp"])\", oauth_token=\"$(options["oauth_token"])\", oauth_version=\"$(options["oauth_version"])\""
    
end

#############################################################
#
# Timelines Functions
#
#############################################################

function mentions_timeline()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_user_timeline(screen_name::String; options = {})
    
    #Make GET call using helper function
    response = twgetappauth("https://api.twitter.com/1.1/statuses/user_timeline.json", 
                            "screen_name",
                            screen_name,
                            options)
    
    #Currently, just returns Response object from Requests.jl
	if response.status == 200
		return response
	else
        #This will return the summary 
		error(response)
	end
end

function home_timeline()
	#Requires user context
	error("Twitter API not fully implemented")
end

function retweets_of_me()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Tweets Functions
#
#############################################################

function get_retweets()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_single_tweet()
	#Requires user context
	error("Twitter API not fully implemented")
end

function destroy_single_tweet()
	#Requires user context
	error("Twitter API not fully implemented")
end

#Need to make this more generalized using options keyword argument
#Currently, function doesn't actually accept options
function post_status_update(status::String; options = Dict())
    
    endpoint = "https://api.twitter.com/1.1/statuses/update.json"
    
    #Add status into options Dict (will get URI encoded automatically in oauth_header
    #Need to URI encode for use in post request (can this be done better?)
    options["status"] = status
    
    #Build oauth_header
    oauth_header_val = oauth_header("POST", endpoint, options)
    
    return Requests.post(URI("https://api.twitter.com/1.1/statuses/update.json"), 
                    "status=$(encodeURI(status))", 
                    {"Content-Type" => "application/x-www-form-urlencoded",
                    "Authorization" => oauth_header_val,
                    "Connection" => "close",
                    "Accept" => "*/*"})
    
end

function get_retweet()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_status_update_media()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_oembed()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_retweeters()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Search Functions
#
#############################################################

function search_tweets(q::String; options = {})
    
    #Make GET call using helper function
    response = twgetappauth("https://api.twitter.com/1.1/search/tweets.json", 
                            "q",
                            q,
                            options)
    
    #Currently, just returns Response object from Requests.jl
	if response.status == 200
		return response
	else
        #This will return the summary 
		error(response)
	end
end

#############################################################
#
# Streaming Functions
#
#############################################################

function get_streaming_filtered()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_streaming_sample()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_firehose()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_user_streaming()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_site_streaming()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Direct Messages Functions
#
#############################################################

function get_direct_messages()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_direct_messages_sent()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_direct_messages_show()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_direct_messages_destroy()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_direct_messages_send()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Friends & Followers Functions
#
#############################################################

function get_friendships_no_retweets()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_friends_ids(screen_name::String; options = {})
    
    #Make GET call using helper function
    response = twgetappauth("https://api.twitter.com/1.1/friends/ids.json", 
                            "screen_name",
                            screen_name,
                            options)
    
    #Currently, just returns Response object from Requests.jl
	if response.status == 200
		return response
	else
        #This will return the summary 
		error(response)
	end
end

function get_followers_ids(screen_name::String; options = {})
    
    #Make GET call using helper function
    response = twgetappauth("https://api.twitter.com/1.1/followers/ids.json", 
                            "screen_name",
                            screen_name,
                            options)
    
    #Currently, just returns Response object from Requests.jl
	if response.status == 200
		return response
	else
        #This will return the summary 
		error(response)
	end
end

function get_friendships_lookup()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_friendships_incoming()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_friendships_outgoing()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_friendships_create()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_friendships_destroy()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_friendships_update()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_friendships_show()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_friends_list(screen_name::String; options = {})
    
    #Make GET call using helper function
    response = twgetappauth("https://api.twitter.com/1.1/friends/list.json", 
                            "screen_name",
                            screen_name,
                            options)
    
    #Currently, just returns Response object from Requests.jl
	if response.status == 200
		return response
	else
        #This will return the summary 
		error(response)
	end
end

function get_followers_list(screen_name::String; options = {})
    
    #Make GET call using helper function
    response = twgetappauth("https://api.twitter.com/1.1/followers/list.json", 
                            "screen_name",
                            screen_name,
                            options)
    
    #Currently, just returns Response object from Requests.jl
	if response.status == 200
		return response
	else
        #This will return the summary 
		error(response)
	end
end

#############################################################
#
# Users Functions
#
#############################################################

function get_account_settings()
	#Requires user context
	error("Twitter API not fully implemented")
end

function validate_credentials()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_account_settings()
	#Requires user context
	error("Twitter API not fully implemented")
end

function update_delivery_device()
	#Requires user context
	error("Twitter API not fully implemented")
end

function update_profile()
	#Requires user context
	error("Twitter API not fully implemented")
end

function update_profile_background()
	#Requires user context
	error("Twitter API not fully implemented")
end

function update_profile_colors()
	#Requires user context
	error("Twitter API not fully implemented")
end

function update_profile_image()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_blocks_list()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_blocks_ids()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_blocks_create()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_blocks_destroy()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_users_lookup()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_users_show()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_users_search()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_users_contributees()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_users_contributors()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_account_remove_profile_banner()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_account_update_profile_banner()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_profile_banner()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Suggested Users Functions
#
#############################################################

function get_users_suggestions_slug()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_users_suggestions()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_users_suggestions_slug_members()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Favorites Functions
#
#############################################################

function get_favorites_list()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_favorites_destroy()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_favorites_create()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Lists Functions
#
#############################################################

function get_lists()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_statuses()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_members_destroy()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_memberships()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_subscribers()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_subscribers_create()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_subscribers_show()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_subscribers_destroy()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_members_createall()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_members_show()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_members()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_members_create()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_destroy()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_update()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_create()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_show()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_subscriptions()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_lists_members_destroyall()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_lists_ownerships()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Saved Searches Functions
#
#############################################################

function get_saved_searches_list()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_saved_searches_id()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_saved_searches_create()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_saved_searches_destroy_id()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Places & Geo Functions
#
#############################################################

function get_geo_id_place_id()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_geo_reverse_geocode()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_geo_search()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_geo_similar_places()
	#Requires user context
	error("Twitter API not fully implemented")
end

function post_geo_place()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# Trends Functions
#
#############################################################

function get_trends_place()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_trends_available()
	#Requires user context
	error("Twitter API not fully implemented")
end

function get_trends_closest()
	#Requires user context
	error("Twitter API not fully implemented")
end

#############################################################
#
# OAuth Functions - One big TODO
#
#############################################################

end # module
