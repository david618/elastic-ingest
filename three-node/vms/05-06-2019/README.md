### Repeat VM Test

** 6 May 2019 **

#### Spark Job

This job using 9 executors each with 5 cores.

```
ssh m1
sudo su - spark
/opt/spark/bin/spark-submit \
  --conf spark.executor.cores=5 \
  --conf spark.cores.max=45 \
  --conf spark.executor.memory=5000m \
  --conf spark.es.batch.size.bytes=421000000 \
  --conf spark.es.batch.size.entries=50000 \
  --conf spark.es.batch.write.refresh=false \
  --conf spark.streaming.concurrentJobs=64 \
  --conf spark.scheduler.mode=FAIR \
  --conf spark.locality.wait=0s  \
  --conf spark.streaming.kafka.consumer.cache.enabled=false \
  --class org.jennings.estest.SendKafkaTopicElasticsearch /home/spark/sparktest/target/sparktest-full.jar \
  spark://m1:7077 1000 a41:9092 group1 planes9 1 \
  a101,a102,a103 9200 - - 9 true false true planes 60s 10000 0 false
```

#### ElasticIndexMon

```
ssh p1
cd rttest
java -cp target/rttest.jar com.esri.rttest.mon.ElasticIndexMon http://a101:9200/planes 10 12
```

#### KafkaTopicMon

```
ssh p1
cd rttest
java -cp target/rttest.jar com.esri.rttest.mon.KafkaTopicMon a41:9092 planes9
```

#### Sending at 400k/s from 1 Test Server

```
ssh a81
bash sendPlanes a41:9092 planes9 planes00000 200 40 2
```

#### Results

KafkaTopicMon: 400k/s

ElasticIndexMon

|Query Number|Sample Number|Epoch (ms)    |Time (s) |Count             |Linear Reg. Rate  |Rate From Previous|Rate From First   |
|------------|-------------|--------------|---------|------------------|------------------|------------------|------------------|
|          1 |           1 |1557158994548 |       0 |        3,067,740 |                  |                  |                  |
|          2 |           2 |1557159004558 |      10 |        9,355,350 |          628,133 |          628,133 |          628,133 |
|          3 |       ***** |1557159014575 |      20 |        9,355,350 |          628,133 |                0 |          313,957 |
|          4 |       ***** |1557159024691 |      30 |        9,355,350 |          628,133 |                0 |          208,593 |
|          5 |       ***** |1557159034554 |      40 |        9,355,350 |          628,133 |                0 |          157,167 |
|          6 |       ***** |1557159044549 |      50 |        9,355,350 |          628,133 |                0 |          125,750 |
|          7 |       ***** |1557159054546 |      59 |        9,355,350 |          628,133 |                0 |          104,797 |
|          8 |           3 |1557159064540 |      69 |       24,961,959 |          294,463 |          260,188 |          312,810 |
|          9 |       ***** |1557159074584 |      80 |       24,961,959 |          294,463 |                0 |          273,555 |
|         10 |       ***** |1557159084544 |      89 |       24,961,959 |          294,463 |                0 |          243,280 |
|         11 |       ***** |1557159094540 |      99 |       24,961,959 |          294,463 |                0 |          218,960 |
|         12 |       ***** |1557159104619 |     110 |       24,961,959 |          294,463 |                0 |          198,910 |
|         13 |       ***** |1557159114537 |     119 |       24,961,959 |          294,463 |                0 |          182,469 |
|         14 |           4 |1557159124611 |     130 |       26,338,704 |          176,406 |           22,919 |          178,921 |
|         15 |           5 |1557159134650 |     140 |       36,901,389 |          199,129 |        1,052,165 |          241,493 |
|         16 |       ***** |1557159144624 |     150 |       36,901,389 |          199,129 |                0 |          225,443 |
|         17 |       ***** |1557159154552 |     160 |       36,901,389 |          199,129 |                0 |          211,455 |
|         18 |       ***** |1557159164545 |     169 |       36,901,389 |          199,129 |                0 |          199,025 |
|         19 |       ***** |1557159174546 |     179 |       36,901,389 |          199,129 |                0 |          187,967 |
|         20 |       ***** |1557159184654 |     190 |       36,901,389 |          199,129 |                0 |          177,973 |
|         21 |           6 |1557159194539 |     199 |       46,512,666 |          200,903 |          160,485 |          217,234 |
|         22 |           7 |1557159204543 |     209 |       51,412,374 |          208,250 |          489,775 |          230,218 |
|         23 |       ***** |1557159214574 |     220 |       51,412,374 |          208,250 |                0 |          219,722 |
|         24 |       ***** |1557159224550 |     230 |       51,412,374 |          208,250 |                0 |          210,192 |
|         25 |       ***** |1557159234550 |     240 |       51,412,374 |          208,250 |                0 |          201,434 |
|         26 |       ***** |1557159244544 |     249 |       51,412,374 |          208,250 |                0 |          193,382 |
|         27 |           8 |1557159254542 |     259 |       53,994,149 |          195,874 |           51,637 |          195,875 |
|         28 |           9 |1557159264541 |     269 |       62,348,105 |          200,355 |          835,479 |          219,563 |
|         29 |          10 |1557159274592 |     280 |       63,802,941 |          202,147 |          144,745 |          216,877 |
|         30 |       ***** |1557159284560 |     290 |       63,802,941 |          202,147 |                0 |          209,423 |
|         31 |       ***** |1557159294545 |     299 |       63,802,941 |          202,147 |                0 |          202,453 |
|         32 |       ***** |1557159304545 |     309 |       63,802,941 |          202,147 |                0 |          195,922 |
|         33 |       ***** |1557159314550 |     320 |       63,802,941 |          202,147 |                0 |          189,796 |
|         34 |          11 |1557159324579 |     330 |       70,617,098 |          199,351 |          136,319 |          204,676 |
|         35 |          12 |1557159334546 |     339 |       75,884,863 |          201,075 |          528,521 |          214,169 |
|         36 |       ***** |1557159344541 |     349 |       75,884,863 |          201,075 |                0 |          208,053 |
|         37 |       ***** |1557159354543 |     359 |       75,884,863 |          201,075 |                0 |          202,273 |
|         38 |       ***** |1557159364546 |     369 |       75,884,863 |          201,075 |                0 |          196,804 |
|         39 |       ***** |1557159374542 |     379 |       75,884,863 |          201,075 |                0 |          191,627 |
|         40 |          13 |1557159384542 |     389 |       76,395,005 |          192,882 |           10,204 |          188,022 |
|         41 |          14 |1557159394543 |     399 |       79,229,379 |          188,666 |          283,409 |          190,406 |
|         42 |          15 |1557159404546 |     409 |       80,000,000 |          185,093 |           77,039 |          187,641 |
|         43 |       ***** |1557159414546 |     419 |       80,000,000 |          185,093 |                0 |          183,173 |
|         44 |       ***** |1557159424543 |     429 |       80,000,000 |          185,093 |                0 |          178,914 |
|         45 |       ***** |1557159434543 |     439 |       80,000,000 |          185,093 |                0 |          174,848 |
|         46 |       ***** |1557159444543 |     449 |       80,000,000 |          185,093 |                0 |          170,962 |
|         47 |       ***** |1557159454542 |     459 |       80,000,000 |          185,093 |                0 |          167,246 |
|         48 |       ***** |1557159464542 |     469 |       80,000,000 |          185,093 |                0 |          163,688 |
|         49 |       ***** |1557159474542 |     479 |       80,000,000 |          185,093 |                0 |          160,278 |
|         50 |       ***** |1557159484546 |     489 |       80,000,000 |          185,093 |                0 |          157,005 |
|         51 |       ***** |1557159494544 |     499 |       80,000,000 |          185,093 |                0 |          153,866 |
|         52 |       ***** |1557159504544 |     509 |       80,000,000 |          185,093 |                0 |          150,849 |
|         53 |       ***** |1557159514544 |     519 |       80,000,000 |          185,093 |                0 |          147,948 |

For last 120  seconds the count has not increased...
Removing sample: 529|80000000
Total Count: 80,000,000 | Linear Regression Rate:  188,666 | Linear Regression Standard Error: 8.30 | Average Rate: 190,406
