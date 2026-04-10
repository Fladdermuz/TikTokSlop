class ProductKnowledge < ApplicationRecord
  belongs_to :product
  belongs_to :imported_by, class_name: "User", optional: true

  validates :product_id, uniqueness: true

  # Build a structured prompt context from the knowledge base for the AI crafter.
  # Returns a multi-line string with labeled sections, skipping blank fields.
  def to_prompt_context
    parts = []
    parts << "Product: #{product.name}" if product
    parts << "Brand: #{brand_name}" if brand_name.present?
    parts << "Short description: #{short_description}" if short_description.present?
    parts << "Full description: #{long_description}" if long_description.present?
    parts << "Key ingredients: #{ingredients}" if ingredients.present?
    parts << "Benefits: #{benefits}" if benefits.present?
    parts << "Target audience: #{target_audience}" if target_audience.present?
    parts << "Use cases: #{use_cases}" if use_cases.present?
    parts << "Unique selling proposition: #{usp}" if usp.present?
    parts << "Size/serving: #{size_or_serving}" if size_or_serving.present?
    parts << "Certifications: #{Array(certifications).join(', ')}" if certifications.present?
    parts << "Brand voice / tone: #{brand_voice}" if brand_voice.present?
    parts << "Warnings: #{warnings}" if warnings.present?
    parts.join("\n")
  end

  def populated?
    [ short_description, long_description, ingredients, benefits, target_audience, usp ].any?(&:present?)
  end
end
