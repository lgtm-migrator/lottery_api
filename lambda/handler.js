const axios = require("axios");
const cheerio = require("cheerio");
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const moment = require("moment");

const baseSiteUrl = "https://www.ohiolottery.com";

const api_version = "v1";
const scratchOffDirectory = "scratchOffs";

const fetchData = async ({item = undefined, attribute = undefined, url, returnCheerio = false}) => {
    const result = await axios.get(url);
    let $ = cheerio.load(result.data);
    if(returnCheerio){
        return $;
    }
    let data = [];
    $(item).each(function(i, elm) {
        let element = $(elm).text().trim();
        if(element !== "../") {
            if(attribute === undefined){
                data.push({"text": element});
            } else {
                let withAttribute = {"text": element};
                withAttribute[attribute] = $(elm).attr(attribute);
                data.push(withAttribute);
            }
        }
    });
    return data;

};

async function uploadToS3(key, data){
    return s3.putObject({
        Bucket: process.env.bucket_name,
        Key: key,
        ACL:'public-read',
        Body: JSON.stringify(data),
        ContentType: "application/json"
    }).promise();
}

async function getGameTypes(){
    let games = await fetchData({item: "h3 a", attribute: "href", url: baseSiteUrl+"/Games/ScratchOffs"});
    games = games.filter(function(value, index, arr){
        return !!value["text"].includes("$");
    });
    return games
}

async function getGamesForType(type){
    let games = await fetchData({item: "a[class=igName]", attribute: "href", url: baseSiteUrl+type["href"]});

    let returnedGames = {};
    for(let game of games){
        returnedGames[gameNameReplacer(game["text"])] = await getGameStats(game);
    }
    return returnedGames;
}

function gameNameReplacer(gameName){
    return gameName
        .replace(/\?/g, "")
        .replace(/\./g, "")
        .replace(/\!/g, "")
        .replace(/\$/g, "")
        .replace(/ /g, "-")
        .toLowerCase();
}

async function getGameStats(game) {
    let $ = await fetchData({url: baseSiteUrl+game["href"], returnCheerio: true});
    let cleanColumns = [];
    $(".tbl_PrizesRemaining table tr").each(function (i, row) {
        if(!$(row).hasClass("table_title")){
            let dirtyColumns = $(row).text().split("\n");
            let cleanRowColumns = [];
            for(let column of dirtyColumns){
                column = column.replace(/\t/g, "");
                if(!$(row).hasClass("col_titles")){
                    column = column.replace(/ /g, "");
                }
                if(column != ""){
                    cleanRowColumns.push(column);
                }
            }
            cleanColumns.push(cleanRowColumns);
        }
    });
    return cleanColumns;
}

async function getScratchoffs(){
    let gameTypes = await getGameTypes();

    let games = {};
    let supportedAmounts = [];
    let supportedGames = [];
    for(let gameType of gameTypes){
        let number = gameType["text"].replace(/\$/g, "").replace(" Games", "");
        supportedAmounts.push(number);
        games[number] = await getGamesForType(gameType);

        // Upload to S3
        await uploadToS3(api_version+"/"+scratchOffDirectory+"/"+number+"/all", games[number]);

        let inThisAmount = [];
        for(let gameKey in games[number]){
            let game = games[number][gameKey];
            inThisAmount.push({name: gameKey, location: "/"+api_version+"/"+scratchOffDirectory+"/"+number+"/"+gameKey});
            await uploadToS3(api_version+"/"+scratchOffDirectory+"/"+number+"/"+gameKey, game);
        }
        await uploadToS3(api_version+"/"+scratchOffDirectory+"/"+number+"/supported", inThisAmount);
        await uploadToS3(api_version+"/"+scratchOffDirectory+"/"+number+"/lastUpdated", {date: moment().format('YYYY-MM-DD hh:mm:ss')});
        supportedGames = [...supportedGames, ...inThisAmount];
    }

    await uploadToS3(api_version+"/"+scratchOffDirectory+"/all", games);
    await uploadToS3(api_version+"/"+scratchOffDirectory+"/supported", {amounts: supportedAmounts, games: supportedGames});
    await uploadToS3(api_version+"/"+scratchOffDirectory+"/lastUpdated", {date: moment().format('YYYY-MM-DD hh:mm:ss')});
}


exports.handler = async function(event, context, callback) {
    await getScratchoffs();
    await uploadToS3(api_version+"/"+"lastUpdated", {date: moment().format('YYYY-MM-DD hh:mm:ss')});
};
