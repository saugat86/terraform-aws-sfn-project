import json

def lambda_handler(event, context):
    print(f'Event: {event}')

    result = {}
    result['statusCode'] = 200
    result['event'] = event

    return json.loads(json.dumps(result, default=str))
