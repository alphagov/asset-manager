# Existing assets

This document is a short overview of the assets currently stored in the NFS mount. On integration the sizes of the directories under `/mnt/uploads` are:

``` bash
@integration-asset-master-1:~$ cd /mnt/uploads/
@integration-asset-master-1:/mnt/uploads$ du -h --max-depth=1
35G ./asset-manager
629G    ./whitehall
7.6M    ./publisher
14G ./support-api
16K ./lost+found
677G    .
```

Comparing this to the [production Grafana dashboard](https://grafana.publishing.service.gov.uk/dashboard/db/assets) (674.99G today) leads me to believe that integration has all of the assets that are on production.

The asset manager application stores a record in MongoDB for each asset. On integration the number of records is

``` bash
@integration-backend-1:/var/apps/asset-manager$ sudo su - deploy
deploy@integration-backend-1:~$ cd /var/apps/asset-manager
deploy@integration-backend-1:/var/apps/asset-manager$ govuk_setenv asset-manager bundle exec rails c
Loading production environment (Rails 4.2.7.1)
irb(main):002:0> Asset.count
=> 57232
```

We generate a list of all the files stored in NFS in the asset manager directory

``` bash
@integration-asset-master-1:/mnt/uploads/asset-manager$ find . -type f | xargs ls -s > ~/file_sizes.txt
```

This indicates that there are 58,613 files in the NFS mount (which is slightly more than the number of records in MongoDB).

``` bash
12:18 $ wc -l file_sizes.txt
   58613 file_sizes.txt
```

I haven't investigated yet why this difference exists. However we can take a look at the file sizes of the files on the mount

``` bash
cat file_sizes.txt | tr -d ' ' | awk -F"[.]/" '{print $1","$2}
```

Loading this file into R allows us to calculate the distribution of file sizes

``` r
library(readr)
d <- read_csv('file_sizes.csv', col_names=c('size', 'filename'))
quantile(d$size, c(.5, .8, .95, .99, 1))
```

```
   50%       80%       95%       99%      100%
204.00    732.00   2376.00   6031.52 174844.00
```

The median file size is 204k, 95% of all assets are under 2.3Mb and the largest asset is just over 174Mb.

## File extensions

We can count the files by extension by splitting the filename on a period ('.') and counting the extensions

``` r
files <- read_csv('~/file_sizes.csv', col_names=c('size', 'filename'))

extensions <- files %>%
  rowwise() %>%
  mutate(ext = tolower(last(unlist(strsplit(filename, '\\.'))))) %>%
  ungroup()

extensions %>%
  group_by(ext) %>%
  summarise(count = n()) %>%
  mutate(freq = percent(count/sum(count))) %>%
  arrange(desc(count)) %>%
  head(20)
```

```
# A tibble: 20 x 3
     ext count  freq
   <chr> <int> <chr>
 1   pdf 56297 96.0%
 2   jpg  1532  2.6%
 3   doc   220  0.4%
 4   png   209  0.4%
 5   gif    78  0.1%
 6  docx    64  0.1%
 7  xlsx    61  0.1%
 8   xls    52  0.1%
 9   odt    28  0.0%
10   ppt    24  0.0%
11   zip     7  0.0%
12   ods     6  0.0%
13  pptx     4  0.0%
14  xlsm     4  0.0%
15   url     3  0.0%
16   csv     2  0.0%
17  jpeg     2  0.0%
18    pd     2  0.0%
19   txt     2  0.0%
20  webp     2  0.0%
```

It is worth noting here that 'pdf' and 'jpg' files (which make up over 98% of the assets stored) are not very compressible using gzip so we may not see any benefit from storing compressed versions of them on S3.
