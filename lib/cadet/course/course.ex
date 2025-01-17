defmodule Cadet.Course do
  @moduledoc """
  Course context contains domain logic for Course administration
  management such as discussion groups and materials
  """
  use Cadet, :context

  import Ecto.Query

  alias Cadet.Accounts.User
  alias Cadet.Course.{Category, Group, Material, Sourcecast, Upload}

  @upload_file_roles ~w(admin staff)a

  @doc """
  Get a group based on the group name or create one if it doesn't exist
  """
  @spec get_or_create_group(String.t()) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t()}
  def get_or_create_group(name) when is_binary(name) do
    Group
    |> where(name: ^name)
    |> Repo.one()
    |> case do
      nil ->
        %Group{}
        |> Group.changeset(%{name: name})
        |> Repo.insert()

      group ->
        {:ok, group}
    end
  end

  @doc """
  Updates a group based on the group name or create one if it doesn't exist
  """
  @spec insert_or_update_group(map()) :: {:ok, %Group{}} | {:error, Ecto.Changeset.t()}
  def insert_or_update_group(params = %{name: name}) when is_binary(name) do
    Group
    |> where(name: ^name)
    |> Repo.one()
    |> case do
      nil ->
        Group.changeset(%Group{}, params)

      group ->
        Group.changeset(group, params)
    end
    |> Repo.insert_or_update()
  end

  # @doc """
  # Reassign a student to a discussion group
  # This will un-assign student from the current discussion group
  # """
  # def assign_group(leader = %User{}, student = %User{}) do
  #   cond do
  #     leader.role == :student ->
  #       {:error, :invalid}

  #     student.role != :student ->
  #       {:error, :invalid}

  #     true ->
  #       Repo.transaction(fn ->
  #         {:ok, _} = unassign_group(student)

  #         %Group{}
  #         |> Group.changeset(%{})
  #         |> put_assoc(:leader, leader)
  #         |> put_assoc(:student, student)
  #         |> Repo.insert!()
  #       end)
  #   end
  # end

  # @doc """
  # Remove existing student from discussion group, no-op if a student
  # is unassigned
  # """
  # def unassign_group(student = %User{}) do
  #   existing_group = Repo.get_by(Group, student_id: student.id)

  #   if existing_group == nil do
  #     {:ok, nil}
  #   else
  #     Repo.delete(existing_group)
  #   end
  # end

  # @doc """
  # Get list of students under staff discussion group
  # """
  # def list_students_by_leader(staff = %User{}) do
  #   import Cadet.Course.Query, only: [group_members: 1]

  #   staff
  #   |> group_members()
  #   |> Repo.all()
  #   |> Repo.preload([:student])
  # end

  @doc """
  Upload a sourcecast file
  """
  def upload_sourcecast_file(uploader = %User{role: role}, attrs = %{}) do
    if role in @upload_file_roles do
      changeset =
        %Sourcecast{}
        |> Sourcecast.changeset(attrs)
        |> put_assoc(:uploader, uploader)

      Repo.insert(changeset)
    else
      {:error, {:forbidden, "User is not permitted to upload"}}
    end
  end

  @doc """
  Delete a sourcecast file
  """
  def delete_sourcecast_file(_deleter = %User{role: role}, id) do
    if role in @upload_file_roles do
      sourcecast = Repo.get(Sourcecast, id)
      Upload.delete({sourcecast.audio, sourcecast})
      Repo.delete(sourcecast)
    else
      {:error, {:forbidden, "User is not permitted to delete"}}
    end
  end

  @doc """
  Create a new folder to put material files in
  """
  def create_material_folder(uploader = %User{}, attrs = %{}) do
    create_material_folder(nil, uploader, attrs)
  end

  def create_material_folder(category, uploader = %User{}, attrs = %{}) do
    changeset =
      %Category{}
      |> Category.changeset(attrs)
      |> put_assoc(:uploader, uploader)

    case category do
      %Category{} ->
        Repo.insert(put_assoc(changeset, :category, category))

      _ ->
        Repo.insert(changeset)
    end
  end

  @doc """
  Upload a material file to designated folder
  """
  def upload_material_file(uploader = %User{}, attrs = %{}) do
    upload_material_file(nil, uploader, attrs)
  end

  def upload_material_file(category, uploader = %User{role: role}, attrs = %{}) do
    if role in @upload_file_roles do
      changeset =
        %Material{}
        |> Material.changeset(attrs)
        |> put_assoc(:uploader, uploader)

      case category do
        %Category{} ->
          Repo.insert(put_assoc(changeset, :category, category))

        _ ->
          Repo.insert(changeset)
      end
    else
      {:error, {:forbidden, "User is not permitted to upload"}}
    end
  end

  @doc """
  Delete a material file
  """
  def delete_material(_deleter = %User{role: role}, id) do
    if role in @upload_file_roles do
      material = Repo.get(Material, id)
      Upload.delete({material.file, material})
      Repo.delete(material)
    else
      {:error, {:forbidden, "User is not permitted to delete"}}
    end
  end

  @doc """
  Delete a category
  A directory tree is deleted recursively
  """
  def delete_category(_deleter = %User{role: role}, id) do
    if role in @upload_file_roles do
      category = Repo.get(Category, id)
      Repo.delete(category)
    else
      {:error, {:forbidden, "User is not permitted to delete"}}
    end
  end

  @doc """
  List material folder content
  """
  def list_material_folders(id) do
    import Cadet.Course.Query

    mat = id |> material_folder_files() |> Repo.all() |> Repo.preload(:uploader)
    cat = id |> category_folder_files() |> Repo.all() |> Repo.preload(:uploader)

    Enum.concat(mat, cat)
  end

  @doc """
  Construct directory tree for current folder
  """
  def construct_hierarchy(id) do
    if is_nil(id) do
      []
    else
      category = Repo.get(Category, id)
      construct_hierarchy(category.category_id) ++ [category]
    end
  end
end
