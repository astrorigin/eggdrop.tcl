#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# pip3 install --upgrade praw

import sys
import praw

# CONFIGURATION
# subreddit name => log file path
subreddits = [
    ['astrology', '/home/eggdrop/eggdrop/myscripts/Reddit/RedditAstrology.txt'],
    ['AskAstrologers', '/home/eggdrop/eggdrop/myscripts/Reddit/RedditAskAstrologers.txt'],
]

# your reddit api stuff here
reddit = praw.Reddit(client_id="blah",
                     client_secret="blah",
                     user_agent="blah",
                     username="blah",
                     password="blah")

# END CONFIG

def readlog(path):
    try:
        f = open(path, 'r')
    except:
        return []
    arr = []
    for line in f:
        line = line.strip()
        if line != '':
            arr.append(line)
    return arr

def writelog(arr, path):
    f = open(path, 'w')
    for a in arr[:100]:
        f.write('%s\n' % a)
    f.close()

def process(sub, logpath):
    global reddit
    subreddit = reddit.subreddit(sub)
    links = readlog(logpath)
    news = {}
    try:
        for post in subreddit.new(limit=100):
            url = post.permalink.strip()
            if url != '':
                if url in links:
                    break
                news[url] = post.title
    except: # reddit made a booboo
        return
    if len(news) == 0:
        return
    for url in news:
        links.insert(0, url)
        print('\x02%s\x02 https://reddit.com%s' % (news[url], url))
    writelog(links, logpath)

if __name__ == '__main__':
    for sub, pth in subreddits:
        process(sub, pth)

# vi: sw=4 ts=4 et
