FROM rocker/tidyverse:3.6.1

RUN R -e 'install.packages("argparse")'
RUN R -e 'install.packages("PRROC")'

COPY score.R /usr/local/bin/score.R