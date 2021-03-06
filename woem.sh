#!/bin/bash

#checks if tor is running
if [[ -z "$(ps -e | grep tor)" ]]
then
    echo 'tor not running, Requires torsocks too'
    exit 0
fi

#remembers working directory for fact selection later. Changes to junk dir later for session cookie and image mess
cwd=$(pwd)
list_of_numbers="$cwd/numbers.txt"

#every valid US area code, used for filtering the numbers list later
valid_area_codes='^(205|251|256|334|938|907|684|480|520|602|623|928|479|501|870|209|213|310|323|408|415|424|442|510|530|559|562|619|626|650|657|661|669|707|714|747|760|805|818|831|858|909|916|925|949|951|303|719|720|970|203|475|860|302|239|305|321|352|386|407|561|727|754|772|786|813|850|863|904|941|954|229|404|470|478|678|706|762|770|912|671|808|208|217|224|309|312|331|618|630|708|773|779|815|847|872|219|260|317|574|765|812|319|515|563|641|712|316|620|785|913|270|502|606|859|225|318|337|504|985|207|240|301|410|443|667|339|351|413|508|617|774|781|857|978|231|248|269|313|517|586|616|734|810|906|947|989|218|320|507|612|651|763|952|228|601|662|769|314|417|573|636|660|816|406|308|402|531|702|725|775|603|201|551|609|732|848|856|862|908|973|505|575|212|315|347|516|518|585|607|631|646|716|718|845|914|917|929|252|336|704|828|910|919|980|984|701|670|216|234|330|419|440|513|567|614|740|937|405|539|580|918|458|503|541|971|215|267|272|412|484|570|610|717|724|814|878|787|939|401|803|843|864|605|423|615|731|865|901|931|210|214|254|281|325|346|361|409|430|432|469|512|682|713|737|806|817|830|832|903|915|936|940|956|972|979|385|435|801|802|340|276|434|540|571|703|757|804|206|253|360|425|509|202|304|681|262|414|534|608|715|920|307)'

#user agent for curl
user_agent='User-Agent:Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.94 Safari/537.36'

#unsubscribe string. Must be 52 characters or less, or have shorter cat facts. spaces = +
#All messages must be a total of 120 characters or less, or they will be truncated by the service
unsub='+To+unsubscribe,+tweet+@Snowden+"Meow,+I+<3+catfacts"'
message_count=0

#makes the junk dir if it doesn't exist
if [ ! -d './junk' ]
then
    mkdir junk
fi
cd './junk'

#function for getting a new tor ip
new_ip(){
    echo 'getting new IP address from TOR'
    pidof tor | xargs sudo kill -HUP
    message_count=0
    sleep 14
}

#function for getting the captcha value and session cookie
get_data() {
    rm -f "$jarfile"
    jar_name="$target_number$carrier"
    img_name="$target_number$carrier"
    captcha=
    #loops until the captcha resolves to 5 valid alpha-numerics
    until [[ -n "$captcha" ]]
    do
        img_url="http://www.watacrackaz.com/autosms/autosms.php?getcode=1"
        torsocks curl -o "$img_name.png" -s "$img_url" -H "$user_agent" -c "$jar_name"
        ((message_count++))
        #makes the captcha image a bit bigger. tesseract was successful more using this
        convert "$img_name.png" -resize 160x60 -gravity center -extent 160x60 "$img_name.jpg"
        #converts the image to a string
        captcha=$(tesseract -psm 4 $img_name.jpg stdout | grep -Eo '^[0-9a-z]{5}$')
        rm -f "$img_name.png"
    done
    rm -f "$img_name.jpg"
}

#function that send the messages
send_message(){
    carrier="$1"
    target_number="$2"
    response=
    #loops until captcha is successful or blocked (tesseract isnt perfect)
    until [[ -n "$response" ]]
    do
        #gets captcha
        get_data
        #url for request
        request_url="http://www.watacrackaz.com/autosms/autosms.php?blob=0.4||$captcha||$carrier||$target_number||$message"
        echo "sending request $request_url"
        #increments message count for IP rotation
        ((message_count++))
        response="$(torsocks curl -s "$request_url" -H "$user_agent" -b $jar_name)"
        echo "$response"
        #filters response for success or blocked
        response="$(echo $response | grep -oE '(From Anonymous|blocked from receiving messages)')"
        #deletes number from list if its blocked
        if [[ "$response" == 'blocked from receiving messages' ]]
        then
            sed -i "/$target_number/d" "$list_of_numbers"
        fi
        #cleans the cookie jar
        rm -f "$jar_name"
    done
}
#infinite loop
while true
do
    #random fact selection
    message="$(shuf $cwd/catfacts.txt | head -1)$unsub"
    #clean numbers.txt for only US area codes
    sed -ri /$valid_area_codes/\!d $list_of_numbers
    #loops through all numbers.txt
    while read number
    do
        #gets new IP every 90 requests
        if [[ $message_count -gt 90 ]]
        then
            sleep 5
            new_ip
        fi
        #limits background jobs and kills hung curls
        try_count=0
        until [[ $(jobs -p | wc -l) -lt 29 ]]
        do
            echo "too many jobs, waiting"
            ((try_count++))
            if [[ $try_count -gt 7 ]]
            then
                pkill -HUP curl
            fi
            sleep 5
        done
        #tries most major US carriers so you don't need a twilio api request to determine it first
        send_message 'AT%26T+USA' "$number" &
        send_message 'Boost+Mobile+USA' "$number" &
        send_message 'Cingular+USA' "$number" &
        send_message 'Cricket+USA' "$number" &
        send_message 'Metro+PCS+USA' "$number" &
        send_message 'Nextel+USA' "$number" &
        send_message 'Sprint+USA' "$number" &
        send_message 'T-Mobile+USA' "$number" &
        send_message 'US+Cellular+USA' "$number" &
        send_message 'Verizon+USA' "$number" &
        send_message 'Virgin+Mobile+USA' "$number" &
        sleep 8
    done <<< "$(tac $list_of_numbers | cut -d':' -f1)"
done
