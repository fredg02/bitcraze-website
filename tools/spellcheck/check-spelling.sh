#!/bin/bash
# requires apt packages: aspell, aspell-en, aspell-fr

# based on https://github.com/eleven-labs/blog.eleven-labs.com/blob/master/bin/check-spelling.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

personalDictionary=aspell.dic.en
api_url=https://api.github.com/repos/bitcraze/bitcraze-website


getMdFiles() {
  MARKDOWN_FILES_CHANGED=`(git diff --name-only $TRAVIS_COMMIT_RANGE || true) | grep .md`
  #MARKDOWN_FILES_CHANGED=`find ../../ -name "*.md"`

  if [ -z "$MARKDOWN_FILES_CHANGED" ]
  then
      echo -e "$GREEN>> No markdown file to check $NC"

      exit 0;
  fi

  echo -e "$BLUE>> Following markdown files were changed in this pull request (commit range: $TRAVIS_COMMIT_RANGE):$NC"
  echo "$MARKDOWN_FILES_CHANGED"
}

removeMetadata() {
  # cat all markdown files that changed
  TEXT_CONTENT_WITHOUT_METADATA=`cat $(echo "$MARKDOWN_FILES_CHANGED" | sed -E ':a;N;$!ba;s/\n/ /g')`
  # remove metadata tags
  TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | grep -v -E '^(layout:|permalink:|date:|date_gmt:|authors:|categories:|tags:|cover:)(.*)'`
  # remove { } attributes
  TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -E 's/\{:([^\}]+)\}//g'`
  # remove <script> content
  TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | perl -0pe 's/<script[^>]*>[^>]*>//gs'`
  # remove html
  TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -E 's/<([^<]+)>//g'`
  # remove code blocks
  TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed  -n '/^\`\`\`/,/^\`\`\`/ !p'`
  # remove code blocks (indented)
  TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed  -e 's/^[[:space:]].*//g'`
  # remove links
  #TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -E 's/http(s)?:\/\/([^ ]+)//g'`
  # remove tags like {% media_gallery %}
  TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -e 's/{%[^{%]*%}//g'`
  # remove image paths
  #TEXT_CONTENT_WITHOUT_METADATA=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | sed -e 's/\/images[^"]*//g'`

  echo -e "$BLUE>> Text content that will be checked (without metadata, html, and links):$NC"
  echo "$TEXT_CONTENT_WITHOUT_METADATA"
}

spellcheck() {
  echo -e "$BLUE>> Checking in 'en' (many technical words are in English anyway)...$NC"
  MISSPELLED=`echo "$TEXT_CONTENT_WITHOUT_METADATA" | aspell --lang=en --encoding=utf-8 --ignore-case --personal=./$personalDictionary list | sort -u`
  # remove words that appear more than once and only differ in case and have 3 or less characters + lazy hack to remove empty entries
  MISSPELLED=`echo "$MISSPELLED" | uniq -u -i | sed -e 's/\b\(\w\)\{,3\}\b//g' | sed '/^$/d'`

  NB_MISSPELLED=`echo "$MISSPELLED" | wc -l`

  if [ "$NB_MISSPELLED" -gt 0 ]
  then
      echo -e "$RED>> $NB_MISSPELLED words that might be misspelled, please check:$NC"
      MISSPELLED=`echo "$MISSPELLED" | sed -E ':a;N;$!ba;s/\n/, /g'`
      echo "$MISSPELLED"
      COMMENT="$NB_MISSPELLED words might be misspelled, please check them: $MISSPELLED"
  else
      COMMENT="No spelling errors, congratulations!"
      echo -e "$GREEN>> $COMMENT $NC"
  fi
}

createPullRequest() {
  echo -e "$BLUE>> Sending results in a comment on the Github pull request #$TRAVIS_PULL_REQUEST:$NC"
  curl -i -H "Authorization: token $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      -X POST -d "{\"body\":\"$COMMENT\"}" \
      $api_url
}

##MAIN
getMdFiles
removeMetadata
spellcheck
#createPullRequest

exit 0