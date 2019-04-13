class AddSlugToJobPosting < ActiveRecord::Migration[5.2]
  def change
    add_column :job_postings, :slug, :string
    add_index :job_postings, :slug, unique: true
  end
end
