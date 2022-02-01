CREATE TABLE admin.deployment_logs

(
	dbv_id
		INT
,	git_commit_id
		TEXT
,	PRIMARY KEY (dbv_id, git_commit_id)
,	date
		TIMESTAMP
		DEFAULT now()
)
;