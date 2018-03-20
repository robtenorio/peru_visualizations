library(pdftools)
library(tidytext)
library(tidyverse)
library(wordcloud)

# *_join doesn't work with regex; there are some English words that aren't important;
# also remove column headers that get messed up
custom_stop_words <- data_frame(word = c("2016", "2017", "missing", "value", 
                                         "tama", "ño", "nombre", "variable", "deci", "males", 
                                         "forma", "to", "etiqueta", "inei", "encuesta", 
                                         "nacional", "hogares", "continua"))

read_delim("stop_words_es.txt", delim = "\t") %>%
  setNames("word") %>%
  bind_rows(custom_stop_words) -> stop_words

# use filter with regex to get the digits instead of using *_join with regex
# group by module using regex to identify module breaks
# start after page 7 - conveniently, pdf_text starts a new line at each page break
"/Users/rtenorio/Documents/portfolio/peru/enaho/2016/546-Modulo01/Diccionario2016.pdf" %>%
  pdf_text %>% data_frame %>%
  setNames("text") %>%
  slice(7:nrow(.)) %>% 
  mutate(module = cumsum(str_detect(text, regex("[[:digit:]]+[.]{1}[[:digit:]]+[.]{1}")))) %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words) %>% 
  filter(!grepl("[[:digit:]]", word)) -> diccionario
  
diccionario %>%
  count(word) %>%
  with(wordcloud(word, n, max.words = 100))

# tf-idf by module as document, word as term
diccionario %>%
  count(module, word) %>%
  ungroup() %>%
  bind_tf_idf(word, module, n) %>%
  arrange(desc(tf_idf)) %>%
  with(wordcloud(word, tf_idf, max.words = 100))

# look at the first six modules
diccionario %>%
  count(module, word) %>%
  filter(module %in% 1:6) %>%
  bind_tf_idf(word, module, n) %>%
  arrange(desc(tf_idf)) %>%
  mutate(word = factor(word, levels = rev(unique(word)))) %>%
  group_by(module) %>%
  top_n(15) %>%
  ungroup() %>%
  ggplot(aes(word, tf_idf)) +
  geom_col(show.legend = FALSE, fill = "#800000") + 
  labs(x = NULL, y = "tf-idf") + 
  facet_wrap(~ module, ncol = 2, scales = "free") + 
  coord_flip()












