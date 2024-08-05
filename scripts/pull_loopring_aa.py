import os
import requests
import csv

# Define the API endpoint and the parameters you are interested in
api_endpoint = 'https://api.growthepie.xyz/v1/fundamentals_full.json'
metric_key = 'daa'
origin_key = 'loopring'
output_csv = os.path.join(os.path.dirname(__file__), '../uploads/loopring_daa.csv')

# Make a GET request to the API endpoint
response = requests.get(api_endpoint)

# Check if the request was successful
if response.status_code == 200:
    data = response.json()
    
    # Filter the data for the specified metric and origin key
    filtered_data = [
        {'date': entry['date'], 'daa': entry['value']}
        for entry in data
        if entry['metric_key'] == metric_key and entry['origin_key'] == origin_key
    ]
    
    # Create the directory if it doesn't exist
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    
    # Write the filtered data to a CSV file
    with open(output_csv, 'w', newline='') as csvfile:
        fieldnames = ['date', 'daa']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for row in filtered_data:
            writer.writerow(row)
    
    print(f'Data successfully written to {output_csv}')
else:
    print(f'Failed to fetch data. HTTP Status code: {response.status_code}')
