import boto3
import json
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_bucket = os.environ['S3_BUCKET']
s3_key = os.environ['S3_KEY']

#################
# Boto3 Clients #
#################
wa_client = boto3.client('wellarchitected')
s3_client = boto3.client('s3')

##############
# Parameters #
##############
# The maximum number of results the API can return in a list workloads call.
list_workloads_max_results_maximum = 50
# The maximum number of results the API can return in a list answers call.
list_answers_max_results_maximum = 50
# The maximum number of results the API can return in a list milestones call.
list_milestone_max_results_maximum = 50


def get_all_workloads():
    # Get a list of all workloads
    list_workloads_result = wa_client.list_workloads(MaxResults=list_workloads_max_results_maximum)
    logger.info(f'Found {len(list_workloads_result)} Well-Archtected workloads.')
    workloads_all = list_workloads_result['WorkloadSummaries']
    while 'NextToken' in list_workloads_result:
        next_token = list_workloads_result['NextToken']
        list_workloads_result = wa_client.list_workloads(
            MaxResults=list_workloads_max_results_maximum, NextToken=next_token
        )
        workloads_all += list_workloads_result['WorkloadSummaries']
    return (workloads_all)

def get_milestones(workload_id):
    # # Get latest milestone review date
    milestones = wa_client.list_milestones(
        WorkloadId=workload_id, MaxResults=list_milestone_max_results_maximum
    )['MilestoneSummaries']

    # If workload has milestone get them.
    logger.info(f'Workload {workload_id} has {len(milestones)} milestones.')
    if milestones:
        for milestone in milestones:
            milestone['RecordedAt'] = milestone['RecordedAt'].isoformat()
    return milestones

def get_lens(workload_id):
    # Which lenses have been activated for this workload
    # print(workload_id)
    lens_reviews_result = wa_client.list_lens_reviews(
        WorkloadId=workload_id
    )['LensReviewSummaries']
    logger.info(f'Workload {workload_id} has used {len(lens_reviews_result)} lens')
    return lens_reviews_result

def get_lens_answers(workload_id, lens_reviews):
    # Loop through each activated lens
    # TODO - List Answers for each milestone
    list_answers_result = []
    for lens in lens_reviews:
        lens_name = lens['LensName']
        logger.info(f'Looking at {lens_name} answers for Workload {workload_id}')

        # Get All answers for the lens
        list_answers_reponse = wa_client.list_answers(
            WorkloadId=workload_id, LensAlias=lens['LensAlias'], MaxResults=list_answers_max_results_maximum
        )

        # Flatten the answer result to include LensAlias and Milestone Number
        for answer_result in list_answers_reponse['AnswerSummaries']:
            answer_result['LensAlias'] = list_answers_reponse['LensAlias']

            # if 'MilestoneNumber' in list_answers_reponse:
            #     print("MILSTONE_DETECTED")
            #     answer_result['MilestoneNumber'] = list_answers_reponse['MilestoneNumber']

            # Append Answers from each lens.  For reporting.
        list_answers_result.extend(list_answers_reponse['AnswerSummaries'])

    return  list_answers_result


def get_lens_summary(workload_id, lens_reviews):
    # Loop through each activated lens
    list_lens_review_summary = []
    for lens in lens_reviews:
        lens_name = lens['LensName']
        logger.info(f'Looking at {lens_name} Summary for Workload {workload_id}')
        list_lens_review_reponse = wa_client.get_lens_review(
            WorkloadId=workload_id, LensAlias=lens['LensAlias']
        )
        list_lens_review_reponse['LensReview']['UpdatedAt'] = list_lens_review_reponse['LensReview']['UpdatedAt'].isoformat()
        list_lens_review_summary.append(list_lens_review_reponse['LensReview'])
    return list_lens_review_summary

def lambda_handler(event, context):
    workloads_all = get_all_workloads()
    # Generate workload JSON file
    logger.info(f'Generate JSON object for each workload.')

    # print (workloads_all)

    for workload in workloads_all:
        # Get workload info from WAR Tool API,
        workload_id = workload['WorkloadId']

        milestones = get_milestones(workload_id)

        lens_reviews = get_lens(workload_id)
        lens_summary_result = get_lens_summary(workload_id, lens_reviews)
        list_answers_result = get_lens_answers(workload_id, lens_reviews)

        # Build JSON of workload data
        workload_report_data = {}
        workload_report_data['workload_id'] = workload['WorkloadId']
        workload_report_data['workload_name'] = workload['WorkloadName']
        workload_report_data['workload_owner'] = workload['Owner']

        workload_report_data['workload_lastupdated'] = workload['UpdatedAt'].isoformat()
        workload_report_data['lens_summary'] = lens_summary_result
        workload_report_data['milestones'] = milestones
        # workload_report_data['report_answers'] = list_answers_result['AnswerSummaries']
        workload_report_data['report_answers'] = list_answers_result
        logger.debug(workload_report_data)
        print(workload_report_data)

        # Write to S3
        file_name = workload_id + '.json'
        logger.info(f'Writing JSON object to s3://{s3_bucket}/{s3_key}{file_name}.')
        s3_client.put_object(
            Body=str(json.dumps(workload_report_data)),
            Bucket=s3_bucket,
            Key=f'{s3_key}{file_name}'
        )