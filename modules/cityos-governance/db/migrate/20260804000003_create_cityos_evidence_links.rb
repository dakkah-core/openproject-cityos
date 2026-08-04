class CreateCityosEvidenceLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :cityos_evidence_links do |t|
      t.references :work_package, null: false, foreign_key: { to_table: :work_packages }
      t.string :evidence_id, null: false
      t.string :evidence_type
      t.string :evidence_uri, null: false
      t.string :evidence_hash, null: false
      t.string :source_commit
      t.string :environment
      t.string :proof_level, null: false
      t.timestamp :produced_at
      t.timestamp :expires_at
      t.string :redaction_class

      t.timestamps
    end

    add_index :cityos_evidence_links, :evidence_id
    add_index :cityos_evidence_links, :proof_level
    add_index :cityos_evidence_links, :expires_at
  end
end
