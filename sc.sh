#!/bin/bash

# Get the list of all your jobs with squeue --me
# job_list=$(squeue --me)
job_list=$(squeue --me -o "%%.$(squeue --me -o %j -h | wc -L)j %i %2t %.$(squeue --me -h -o %b | wc -L)b %.$(squeue --me -h -o %M | wc -L)M %.7k %.$(squeue --me -h -o %R | wc -L )R")

# Check if there are any jobs to list
if [[ -z "$job_list" ]]; then
        echo "No jobs found."
            exit 0
fi

# Print header
echo "Your jobs:"

# Numerate and print each job
index=0
job_ids=(0)
while IFS= read -r line; do
    if [[ $index -ne 0 ]]; then # Skip the header line
        echo "$index   $line"
        job_id=$(echo $line | awk '{print $2}')
        job_ids=(${job_ids[@]} $job_id)
    else
        echo "   $line" # Print header
    fi
    index=$((index + 1))
done <<< "$job_list"

# Offer an input line to cancel the respective process
read -p "Enter the number of the job to cancel: " job_number

# Check if input is a number and within the range
if ! [[ "$job_number" =~ ^[0-9]+$ ]] || [[ "$job_number" -lt 1 ]] || [[ "$job_number" -ge "$index" ]]; then
    echo "Invalid job number."
    exit 1
fi

# Extract the JobID of the selected job
job_id="${job_ids[$job_number]}"

echo "Selected job with jobID $job_id - cancelling job \"$(squeue -h -j $job_id -o %j)\" ..." 

# Cancel the selected job
scancel "$job_id"

echo "Job $job_id has been cancelled."
