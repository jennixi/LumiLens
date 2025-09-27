#include <curl/curl.h>

int post_file(const char* url, const char* field, const char* path) {
  CURL *h = curl_easy_init(); if(!h) return -1;
  struct curl_httppost *form=NULL,*last=NULL;
  curl_formadd(&form,&last,CURLFORM_COPYNAME,field,CURLFORM_FILE,path,CURLFORM_END);
  curl_easy_setopt(h, CURLOPT_URL, url);
  curl_easy_setopt(h, CURLOPT_HTTPPOST, form);
  curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 3L);
  curl_easy_setopt(h, CURLOPT_TIMEOUT, 5L);
  int rc = curl_easy_perform(h);
  curl_formfree(form); curl_easy_cleanup(h);
  return rc;
}