-- Create feedback table for user feedback submissions
CREATE TABLE IF NOT EXISTS feedback (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  feedback_type VARCHAR(50) NOT NULL CHECK (feedback_type IN ('General Feedback', 'Report a Bug', 'Feature Request')),
  message TEXT NOT NULL,
  email VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- Create RLS policy: Users can view their own feedback
CREATE POLICY "Users can view their own feedback"
  ON feedback
  FOR SELECT
  USING (auth.uid() = user_id OR user_id IS NULL);

-- Create RLS policy: Users can insert their own feedback
CREATE POLICY "Users can insert their own feedback"
  ON feedback
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Create index on user_id and created_at for efficient queries
CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_type ON feedback(feedback_type);
