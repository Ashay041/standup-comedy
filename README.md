Demo: https://drive.google.com/file/d/1_0B85GjBt7xw6mqklpSq_EvvbcCKRwN8/view?uuspdrive_link

Designed AI agent evaluation benchmark using LLM-as-judge (Gemini) to score multi-agent conversations by implementing AutoGen GroupChat with custom routing and deploying parallel Harbor execution in Daytona containers.

It is a multi-agent flow where you select 2 agents (well known commedians) amongst whom you want to have the standup battle and there is a ToxicityChecker agent in between them that only only allows selected conversations to pass to the other comedian. The other agent - LLM as a judge gives a score and tells which LLM model was more funny!
