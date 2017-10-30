#!/bin/sh

    sh /tests/wait-for-url.sh $DECISIONRUNNER:9080/DecisionRunner
    sh /tests/wait-for-url.sh $DECISIONSERVERRUNTIME:9080/DecisionService resExecutor resExecutor
    sh /tests/wait-for-url.sh $DECISIONCENTER:9060/decisioncenter
    sh /tests/wait-for-url.sh $DECISIONCENTER:9060/teamserver
    sh /tests/wait-for-url.sh $DECISIONSERVERCONSOLE:9080/res
