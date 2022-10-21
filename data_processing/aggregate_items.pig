set mapred.output.compress true
set pig.splitCombination true
set pig.maxCombinedSplitSize 1073741824
set pig.minCombinedSplitSize 1073741824
set mapreduce.job.reduce.slowstart.completedmaps 1.0
set mapred.reduce.tasks.speculative.execution true
set mapred.map.tasks.speculative.execution true
set job.name 'agg_items'

SET output.compression.enabled true;
SET output.compression.codec org.apache.hadoop.io.compress.GzipCodec;
REGISTER 'jyson-1.0.2/lib/jyson-1.0.2.jar';
REGISTER 'amazon_data_udf.py' using jython AS udf;


%DEFAULT input_file '$HDFS_ROOT/amazon_data_processed/user_aggregated.new.tsv'
%DEFAULT output_file '$HDFS_ROOT/amazon_data_processed/user_aggregated.item_aggregated.tsv'
%DEFAULT num_parallel 1000

/*
%DEFAULT output_file 'w'
%DEFAULT input_file 'y'
%DEFAULT num_parallel 1
*/

loaded = load '$input_file' using PigStorage('\t', '-schema');

generated = foreach loaded generate asin_hist, price_hist, overall_hist, brand_hist,
        unixReviewTime_hist, category_hist, overall, reviewerID, asin, reviewText,
        summary, unixReviewTime, category, description, title, also_buy, feature,
        rank, price, also_view, details, main_cat, similar_item, brand;

grouped = foreach (group generated by asin parallel $num_parallel) {
        generate flatten(generated) as (asin_hist, price_hist, overall_hist, brand_hist,
        unixReviewTime_hist, category_hist, overall, reviewerID, asin, reviewText,
        summary, unixReviewTime, category, description, title, also_buy, feature,
        rank, price, also_view, details, main_cat, similar_item, brand),
        flatten(udf.TallyOverall(generated.overall)) as
        (asin_overall_cnt_1, asin_overall_cnt_2, asin_overall_cnt_3, asin_overall_cnt_4,
        asin_overall_cnt_5), COUNT(generated.overall) as asin_overall_cnt;
};
grouped2 = foreach (group grouped by reviewerID parallel $num_parallel) {
        generate flatten(grouped) as (asin_hist, price_hist, overall_hist, brand_hist,
        unixReviewTime_hist, category_hist, overall, reviewerID, asin, reviewText,
        summary, unixReviewTime, category, description, title, also_buy, feature,
        rank, price, also_view, details, main_cat, similar_item, brand, asin_overall_cnt_1,
        asin_overall_cnt_2,
        asin_overall_cnt_3, asin_overall_cnt_4, asin_overall_cnt_5, asin_overall_cnt),
        flatten(udf.TallyOverall(grouped.overall)) as (reviewer_overall_cnt_1,
        reviewer_overall_cnt_2, reviewer_overall_cnt_3, reviewer_overall_cnt_4,
        reviewer_overall_cnt_5), COUNT(grouped.overall) as reviewer_overall_cnt;
}

rmf $output_file
STORE grouped2 into '$output_file' using PigStorage('\t', '-schema');