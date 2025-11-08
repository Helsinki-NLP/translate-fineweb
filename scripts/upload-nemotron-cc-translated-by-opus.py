import os
from huggingface_hub import HfApi, CommitOperationAdd
from huggingface_hub.utils import HfHubHTTPError

def upload_missing_parquet_files(base_path, repo_id, batch_size=10):
    """
    Checks for existing files and uploads only the missing Parquet files from 
    specified language folders to a Hugging Face dataset using batch commits.

    Args:
        base_path (str): The absolute path to the directory containing the language folders.
        repo_id (str): The ID of the Hugging Face dataset repository.
        batch_size (int): Number of files to upload per commit (default: 50).
                         Adjust based on file sizes and network conditions.
    """
    api = HfApi()
    languages = ["bos", "cat", "dan", "ell", "eng", "eus", "fra", "glg", "hun", "hrv", "ita", "lit", "nld", "nob", "por", "slk", "spa", "srp_Cyrl", "tur",
                 "bul", "ces", "deu", "est", "fin", "gle", "hrv", "isl", "kat", "lav", "mkd", "mlt", "nno", "pol", "ron", "slv", "sqi", "swe", "ukr"]

    # --- Get the list of existing files in the repository ---
    print(f"Connecting to '{repo_id}' to get the list of existing files...")
    try:
        repo_files = set(api.list_repo_files(repo_id=repo_id, repo_type="dataset"))
        print(f"Found {len(repo_files)} files already on the Hub.")
    except HfHubHTTPError as e:
        print(f"Could not connect to the repository. Please check if the repo ID is correct and you have access rights. Error: {e}")
        return
    # ----------------------------------------------------

    print("\nStarting to check local files and prepare upload list...")

    # Collect all files that need to be uploaded
    all_operations = []
    total_files_to_upload = 0
    
    for lang in languages:
        lang_path = os.path.join(base_path, lang)
        if not os.path.isdir(lang_path):
            print(f"Directory for language '{lang}' not found. Skipping.")
            continue

        files = [f for f in os.listdir(lang_path) if f.endswith(".parquet")]
        
        if not files:
            print(f"No Parquet files found in the '{lang}' directory. Skipping.")
            continue

        print(f"Checking language: {lang}...")
        
        for filename in files:
            repo_file_path = f"{lang}/{filename}"
            # Check if the file needs to be uploaded
            if repo_file_path not in repo_files:
                local_file_path = os.path.join(lang_path, filename)
                all_operations.append(
                    CommitOperationAdd(
                        path_in_repo=repo_file_path,
                        path_or_fileobj=local_file_path
                    )
                )
                total_files_to_upload += 1
    
    if not all_operations:
        print("\nAll files are already on the Hub. Nothing to upload.")
        return
    
    print(f"\n{'='*60}")
    print(f"Total files to upload: {total_files_to_upload}")
    print(f"Batch size: {batch_size} files per commit")
    print(f"Estimated commits: {(total_files_to_upload + batch_size - 1) // batch_size}")
    print(f"{'='*60}\n")

    # Upload in batches to avoid rate limiting
    for batch_num, i in enumerate(range(0, len(all_operations), batch_size), 1):
        batch = all_operations[i:i + batch_size]
        batch_end = min(i + batch_size, len(all_operations))
        
        print(f"Uploading batch {batch_num} (files {i+1}-{batch_end} of {total_files_to_upload})...")
        
        try:
            api.create_commit(
                repo_id=repo_id,
                repo_type="dataset",
                operations=batch,
                commit_message=f"Upload batch {batch_num}: {len(batch)} files (files {i+1}-{batch_end})"
            )
            print(f"  ✓ Successfully uploaded batch {batch_num} ({len(batch)} files)")
        except Exception as e:
            print(f"  ✗ FAILED to upload batch {batch_num}. Error: {e}")
            print(f"    Files in this batch:")
            for op in batch:
                print(f"      - {op.path_in_repo}")

    print("\n" + "="*60)
    print("Process finished. All missing files have been attempted.")
    print("="*60)

if __name__ == "__main__":
    path_to_data = "/scratch/project_462000964/tiedeman/translate-fineweb/maxidl/nemotron-cc-english-run1/translated/jsonl"
    dataset_repo_id = "Helsinki-NLP/nemotron-cc-translated"
    upload_missing_parquet_files(path_to_data, dataset_repo_id)
