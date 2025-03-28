from botocore.exceptions import ClientError
import copy
import datetime
import yaml

from boto_common import *

COMPLIANCE = "COMPLIANCE"
GOVERNANCE = "GOVERNANCE"

data1M  = b"0" * 1024 * 1024 * 1
data5M  = b"0" * 1024 * 1024 * 5

ENDPOINT = "http://127.0.0.1:8080"
SECRET = ""
AWS_ACCESS_KEY_ID = ""
AWS_SECRET_ACCESS_KEY = ""

TEST_SPEC = "obj_lock_tests.yaml"


def add_days(d, days):
    return d + datetime.timedelta(days=days)


def add_years(d, years):
    """
    Return a date that's `years` years after the date (or datetime)
    object `d`. Return the same calendar date (month and day) in the
    destination year, if it exists, otherwise use the following day
    (thus changing February 29 to March 1).
    """
    try:
        return d.replace(year = d.year + years)
    except ValueError:
        return d + (datetime.date(d.year + years, 1, 1) - datetime.date(d.year, 1, 1))


def validate_retain_until_date(retain_until_date):
    if retain_until_date is None:
        return None

    return datetime.datetime.strptime(retain_until_date, "%Y-%m-%dT%H:%M:%S%z")


def serialize_retain_until_date(retain_until_date):
    return retain_until_date.strftime('%Y-%m-%dT%H:%M:%S%z')


def action_setup(client, bucket, key, ctx=None):
    pass


def action_create_bucket(client, bucket, key, ctx=None, LockEnabled=None):
    if LockEnabled is not None:
        return client.create_bucket(
            Bucket=bucket,
            ObjectLockEnabledForBucket=LockEnabled,
        )
    else:
        return client.create_bucket(
            Bucket=bucket,
        )


def action_enable_versioning(client, bucket, key, ctx=None):
    return client.put_bucket_versioning(
        Bucket=bucket,
        VersioningConfiguration={
            "Status": "Enabled",
        },
    )


def action_get_versioning(client, bucket, key, ctx=None):
    return client.get_bucket_versioning(
        Bucket=bucket,
    )


def action_put_obj_lock_config(client, bucket, key, ctx=None, Mode=None, Days=None, Years=None):
    if Mode is None:
        ctx.DefaultRetention = None
    else:
        ctx.DefaultRetention = {}
        ctx.DefaultRetention["Mode"] = Mode
        if Days:
            ctx.DefaultRetention["Days"] = Days
        if Years:
            ctx.DefaultRetention["Years"] = Years

    if ctx.DefaultRetention is None:
        return client.put_object_lock_configuration(
            Bucket=bucket,
            ObjectLockConfiguration={
                "ObjectLockEnabled": "Enabled",
            },
        )
    else:
        return client.put_object_lock_configuration(
            Bucket=bucket,
            ObjectLockConfiguration={
                "ObjectLockEnabled": "Enabled",
                "Rule": {
                    "DefaultRetention": ctx.DefaultRetention,
                },
            },
        )


def action_put_object(client, bucket, key, ctx=None, Mode=None, Date=None):
    ctx.Mode = Mode
    ctx.Date = Date
    if Mode is None and Date is None:
        resp = client.put_object(
            Bucket=bucket,
            Key=key,
            Body=data1M,
        )
    elif Mode is None:
        resp = client.put_object(
            Bucket=bucket,
            Key=key,
            Body=data1M,
            ObjectLockRetainUntilDate=Date,
        )
    elif Date is None:
        resp = client.put_object(
            Bucket=bucket,
            Key=key,
            Body=data1M,
            ObjectLockMode=Mode,
        )
    else:
        resp = client.put_object(
            Bucket=bucket,
            Key=key,
            Body=data1M,
            ObjectLockMode=Mode,
            ObjectLockRetainUntilDate=Date,
        )
    ctx.VersionId = resp.get("VersionId", None)
    ctx.CreationDate = resp.get("ResponseMetadata", {}).get("HTTPHeaders", {}).get("date", None)
    return resp


def action_create_mp(client, bucket, key, ctx=None, Mode=None, Date=None):
    ctx.Mode = Mode
    ctx.Date = Date
    if Mode is None and Date is None:
        resp = client.create_multipart_upload(
            Bucket=bucket,
            Key=key,
        )
    elif Mode is None:
        resp = client.create_multipart_upload(
            Bucket=bucket,
            Key=key,
            ObjectLockRetainUntilDate=Date,
        )
    elif Date is None:
        resp = client.create_multipart_upload(
            Bucket=bucket,
            Key=key,
            ObjectLockMode=Mode,
        )
    else:
        resp = client.create_multipart_upload(
            Bucket=bucket,
            Key=key,
            ObjectLockMode=Mode,
            ObjectLockRetainUntilDate=Date,
        )

    ctx.CreationDate = resp.get("ResponseMetadata", {}).get("HTTPHeaders", {}).get("date", None)
    
    UploadId = resp.get("UploadId", None)

    resp = client.upload_part(
        Bucket=bucket,
        Key=key,
        UploadId=UploadId,
        PartNumber=1,
        Body=data5M,
    )

    ETag = resp.get("ETag", None)

    Parts = [{
        "ETag": ETag,
        "PartNumber": 1,
    }]

    resp = client.complete_multipart_upload(
        Bucket=bucket,
        Key=key,
        UploadId=UploadId,
        MultipartUpload={
            "Parts": Parts,
        },
    )
    ctx.VersionId = resp.get("VersionId", None)
    return resp


def action_copy_object(client, bucket, key, ctx=None, Mode=None, Date=None):
    ctx.Mode = Mode
    ctx.Date = Date
    client.put_object(
        Bucket=bucket,
        Key=f"other-{key}",
        Body=data1M,
    )
    if Mode is None and Date is None:
        resp = client.copy_object(
            Bucket=bucket,
            Key=key,
            CopySource=f"{bucket}/other-{key}",
        )
    elif Mode is None:
        resp = client.copy_object(
            Bucket=bucket,
            Key=key,
            CopySource=f"{bucket}/other-{key}",
            ObjectLockRetainUntilDate=Date,
        )
    elif Date is None:
        resp = client.copy_object(
            Bucket=bucket,
            Key=key,
            CopySource=f"{bucket}/other-{key}",
            ObjectLockMode=Mode,
        )
    else:
        resp = client.copy_object(
            Bucket=bucket,
            Key=key,
            CopySource=f"{bucket}/other-{key}",
            ObjectLockMode=Mode,
            ObjectLockRetainUntilDate=Date,
        )
    ctx.VersionId = resp.get("VersionId", None)
    ctx.CreationDate = resp.get("ResponseMetadata", {}).get("HTTPHeaders", {}).get("date", None)
    return resp


def action_delete_object(client, bucket, key, ctx=None):
    return client.delete_object(
        Bucket=bucket,
        Key=key,
    )


def action_delete_version(client, bucket, key, ctx=None):
    return client.delete_object(
        Bucket=bucket,
        Key=key,
        VersionId=ctx.VersionId,
    )


def action_get_object_retention(client, bucket, key, ctx=None):
    return client.get_object_retention(
        Bucket=bucket,
        Key=key,
    )


def action_put_object_retention(client, bucket, key, ctx=None, Mode=None, Date=None):
    if Mode is None and Date is None:
        return client.put_object_retention(
            Bucket=bucket,
            Key=key,
        )
    elif Mode is None:
        ctx.Retention = {
            "RetainUntilDate": Date,
        }
        return client.put_object_retention(
            Bucket=bucket,
            Key=key,
            Retention=ctx.Retention,
        )
    elif Date is None:
        ctx.Retention = {
            "Mode": Mode,
        }
        return client.put_object_retention(
            Bucket=bucket,
            Key=key,
            Retention=ctx.Retention,
        )
    else:
        ctx.Retention = {
            "Mode": Mode,
            "RetainUntilDate": Date,
        }
        return client.put_object_retention(
            Bucket=bucket,
            Key=key,
            Retention=ctx.Retention,
        )


def err_code(err):
    return err.response.get("Error", {}).get("Code", None)


def assert_err_code(client, bucket, key, ctx=None, Code=None):
    assert ctx.err is not None, "err is None"
    assert err_code(ctx.err) == Code, f"Error.Code is {err_code(ctx.err)}, should be {Code}"
    ctx.err = None


def assert_default_retention(client, bucket, key, ctx=None, DefaultRetention=None):
    resp = client.get_object_lock_configuration(
        Bucket=bucket,
    )
    current = resp.get("ObjectLockConfiguration", {}).get("Rule", {}).get("DefaultRetention", None)
    print(current)
    assert current == DefaultRetention


def assert_retention(client, bucket, key, ctx=None, Retention=None):
    resp = client.get_object_retention(
        Bucket=bucket,
        Key=key,
    )
    Retention["RetainUntilDate"] = validate_retain_until_date(Retention["RetainUntilDate"])
    current = resp.get("Retention", None)
    print(current, Retention)
    assert current == Retention


ACTIONS = {
    "setup":                              action_setup,
    
    "create-bucket":                      action_create_bucket,

    "enable-versioning":                  action_enable_versioning,
    "action_get_versioning":              action_get_versioning,
    
    "put-obj-lock-config":                action_put_obj_lock_config,

    "put-object":                         action_put_object,
    "create-mp":                          action_create_mp,
    "copy-object":                        action_copy_object,
    
    "delete-object":                      action_delete_object,
    "delete-version":                     action_delete_version,

    "get-object-retention":               action_get_object_retention,
    "put-object-retention":               action_put_object_retention,

    "err-code":                           assert_err_code,

    "default-retention":                  assert_default_retention,
    "retention":                          assert_retention,
}


class TestCtx:
    def __init__(self):
        self.account = AccountData(f"acc-{uuid4()}"[:8])
        
        # Linha para testar SAIO
        self.client = create_client_for_saio(self.account, ENDPOINT, SECRET)

        # Linha para testar PROD
        # self.client = boto3.client(
        #     service_name="s3",
        #     endpoint_url=ENDPOINT,
        #     aws_access_key_id=AWS_ACCESS_KEY_ID,
        #     aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
        #     config=CONFIG,
        #     verify=False,
        # )
        
        self.bucket = f"bkt-{uuid4()}"[:8]
        self.key = f"key-{uuid4()}"[:8]
        self.err = None


def dfs(tree, stack=None):
    if stack is None:
        stack = []
    for k, v in tree.items():
        stack.append(k)
        for c in v:
            if isinstance(c, dict):
                yield from dfs(c, stack)
            else:
                stack.append(c)
                yield copy.copy(stack)
                stack.pop()
        stack.pop()


def decompress_test_case(compressed_test_case):
    if len(compressed_test_case) == 0:
        yield []
        return

    last = compressed_test_case.pop()

    if last.startswith("assert "):
        actions = [last.replace("assert ", "").split(" ")]
    else:
        actions = map(lambda a: [a], last.split(" "))

    for test_case in decompress_test_case(compressed_test_case):
        for action in actions:
            some_test_case = copy.copy(test_case)
            some_test_case.append(action)
            yield some_test_case


def exec_test_case(test_case):
    ctx = TestCtx()

    print()
    for actions in test_case:
        for action_spec in actions:
            action_name, *action_spec = action_spec.split("=", 1)
            
            kwargs = {}
            if len(action_spec) > 0:
                kwargs = json.loads(action_spec[0])

            action = ACTIONS.get(action_name, None)
            if action is None:
                raise ValueError(f"Invalid action '{action_name}'")
            
            print(action_name, kwargs)

            try:
                action(ctx.client, ctx.bucket, ctx.key, ctx, **kwargs)
            except ClientError as err:
                print("ERROR", err)
                if ctx.err:
                    raise ctx.err
                ctx.err = err

    if ctx.err is not None:
        raise ctx.err


def main():
    with open(TEST_SPEC, "r") as file:
        test_spec = yaml.safe_load(file)

    counter = 0

    for compressed_test_case in dfs(test_spec):
        for test_case in decompress_test_case(compressed_test_case):
            counter += 1
            exec_test_case(test_case)

    print(f"Total: {counter}")


if __name__ == "__main__":
    main()