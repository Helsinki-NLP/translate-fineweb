
from huggingface_hub import HfApi, CommitOperationAdd
from huggingface_hub.utils import HfHubHTTPError


#    repo_id = "Helsinki-NLP/fineweb-edu-translated"
#    repo_id = "Helsinki-NLP/nemotron-cc-translated"

if __name__ == "__main__":
    tag = 'v1.1'
    repo_id = "Helsinki-NLP/fineweb-edu-translated"
    api = HfApi()
    api.create_tag(repo_id=repo_id, repo_type="dataset",tag=tag)
