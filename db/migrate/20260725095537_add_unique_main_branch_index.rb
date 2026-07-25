class AddUniqueMainBranchIndex < ActiveRecord::Migration[7.2]
  def change
    add_index :branches,
              :organization_id,
              unique: true,
              where: "main = TRUE",
              name: "index_branches_on_one_main_per_organization"
  end
end
