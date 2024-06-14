def lambda_handler(event, context):
   print(event)
   message = 'Hello {} !'.format(event['username'])
   return {
       'message' : message,
       'data':'test',
       'example':'testing'
   }